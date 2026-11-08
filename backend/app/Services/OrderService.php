<?php

namespace App\Services;

use App\Enums\DeliveryMethod;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethodType;
use App\Enums\PaymentStatus;
use App\Exceptions\ConflictException;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Coupon;
use App\Models\Order;
use App\Models\ProductVariant;
use App\Models\User;
use App\Support\MediaUrl;
use App\Support\Money;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class OrderService
{
    public function __construct(private readonly CartService $carts) {}

    /**
     * Place an order from the user's server-side cart.
     *
     * @param  array{address_id: int, payment_method_id: int, delivery_method?: ?string, note?: ?string}  $data
     * @return array{0: Order, 1: bool} the order, and whether it was created by this call
     */
    public function place(User $user, array $data, ?string $idempotencyKey = null): array
    {
        if ($idempotencyKey && ($existing = $this->findByKey($user, $idempotencyKey))) {
            return [$existing, false];
        }

        try {
            return DB::transaction(fn () => $this->placeLocked($user, $data, $idempotencyKey));
        } catch (UniqueConstraintViolationException $e) {
            // A concurrent retry with the same Idempotency-Key won the race.
            if ($idempotencyKey && ($existing = $this->findByKey($user, $idempotencyKey))) {
                return [$existing, false];
            }

            throw $e;
        }
    }

    /**
     * @return array{0: Order, 1: bool}
     */
    private function placeLocked(User $user, array $data, ?string $idempotencyKey): array
    {
        // Serialises checkouts of the same user.
        $cart = Cart::where('user_id', $user->id)->lockForUpdate()->first();

        if ($idempotencyKey && ($existing = $this->findByKey($user, $idempotencyKey))) {
            return [$existing, false];
        }

        if (! $cart || ! $cart->items()->exists()) {
            throw ValidationException::withMessages(['cart' => ['Your cart is empty.']]);
        }

        // Only the selected items are ordered; the rest stay in the cart.
        if (! $cart->items()->where('is_selected', true)->exists()) {
            throw ValidationException::withMessages(['cart' => ['Please select at least one item to check out.']]);
        }

        // Re-read inside the transaction: both must still belong to this user.
        $address = $user->addresses()->find($data['address_id']);
        $paymentMethod = $user->paymentMethods()->find($data['payment_method_id']);

        if (! $address || ! $paymentMethod) {
            throw ValidationException::withMessages(array_filter([
                'address_id' => $address ? null : ['Please add or select a shipping address.'],
                'payment_method_id' => $paymentMethod ? null : ['Please add or select a payment method.'],
            ]));
        }

        if ($paymentMethod->isExpired()) {
            throw ValidationException::withMessages([
                'payment_method_id' => ['This card has expired. Please choose another payment method.'],
            ]);
        }

        // Lock every variant in a fixed order to avoid deadlocks between checkouts.
        $variantIds = $cart->items()->where('is_selected', true)->pluck('product_variant_id')->sort()->values();
        $variants = ProductVariant::whereIn('id', $variantIds)->orderBy('id')->lockForUpdate()->get()->keyBy('id');

        if ($cart->coupon_id) {
            Coupon::whereKey($cart->coupon_id)->lockForUpdate()->first();
        }

        // Fresh prices, stock and coupon state, read after the locks.
        $cart->unsetRelations();
        $summary = $this->carts->summarize($cart, DeliveryMethod::from($data['delivery_method'] ?? DeliveryMethod::Standard->value));

        $this->assertStock($summary['selected_lines'], $variants);

        if ($summary['coupon'] && $summary['coupon_error']) {
            throw new ConflictException($summary['coupon_error'], ['coupon' => $summary['coupon']->code]);
        }

        $isCard = $paymentMethod->type === PaymentMethodType::Card;

        $order = Order::create([
            'number' => $this->newOrderNumber(),
            'user_id' => $user->id,
            'idempotency_key' => $idempotencyKey,
            'status' => OrderStatus::Pending,
            'currency' => $summary['currency'],
            'subtotal' => Money::format($summary['subtotal']),
            'discount_total' => Money::format($summary['discount']),
            'shipping_total' => Money::format($summary['shipping']),
            'grand_total' => Money::format($summary['grand']),
            'coupon_id' => $summary['coupon']?->id,
            'coupon_code' => $summary['coupon']?->code,
            'delivery_method' => $summary['delivery_method'],
            'payment_method_id' => $paymentMethod->id,
            'payment_method' => $paymentMethod->type,
            'payment_method_label' => $paymentMethod->label,
            // Card payments are only marked paid by a trusted provider webhook.
            'payment_status' => $isCard ? PaymentStatus::Pending : PaymentStatus::Unpaid,
            'address_id' => $address->id,
            'shipping_label' => $address->label,
            'shipping_recipient_name' => $address->recipient_name,
            'shipping_phone' => $address->phone,
            'shipping_line1' => $address->line1,
            'shipping_line2' => $address->line2,
            'shipping_city' => $address->city,
            'shipping_state' => $address->state,
            'shipping_postal_code' => $address->postal_code,
            'shipping_country_code' => $address->country_code,
            'note' => $data['note'] ?? null,
            'placed_at' => now(),
        ]);

        foreach ($summary['selected_lines'] as $line) {
            $variant = $line['variant'];
            $product = $variant->product;

            $order->items()->create([
                'product_id' => $product->id,
                'product_variant_id' => $variant->id,
                'product_title' => $product->title,
                'sku' => $variant->sku,
                'color' => $variant->color,
                'size' => $variant->size,
                'image_url' => MediaUrl::resolve($product->images->first()?->url),
                'unit_price' => Money::format($line['unit']),
                'quantity' => $line['item']->quantity,
                'line_total' => Money::format($line['total']),
            ]);

            $variants[$variant->id]->decrement('stock_quantity', $line['item']->quantity);
            $product->increment('sold_count', $line['item']->quantity);
        }

        if ($summary['coupon']) {
            $summary['coupon']->increment('used_count');
        }

        // Remove the ordered items only once everything above has succeeded.
        $cart->items()->where('is_selected', true)->delete();
        $cart->coupon()->dissociate()->save();

        $user->appNotifications()->create([
            'type' => 'order_placed',
            'title' => 'Order placed',
            'body' => "Your order {$order->number} has been placed. Total: {$order->grand_total} {$order->currency}.",
            'data' => ['order_id' => $order->id],
        ]);

        return [$order, true];
    }

    /**
     * @param  list<array{item: CartItem, variant: ProductVariant}>  $lines
     * @param  Collection<int, ProductVariant>  $locked  variants re-read under a row lock
     */
    private function assertStock(array $lines, Collection $locked): void
    {
        $problems = [];

        foreach ($lines as $line) {
            $variant = $line['variant'];
            $current = $locked[$variant->id] ?? null;
            $requested = $line['item']->quantity;

            if (! $current || ! $variant->isPurchasable() || ! $current->is_active) {
                $problems[] = ['product_variant_id' => $variant->id, 'title' => $variant->product?->title, 'requested' => $requested, 'available' => 0, 'reason' => 'unavailable'];
            } elseif ($current->stock_quantity < $requested) {
                $problems[] = ['product_variant_id' => $variant->id, 'title' => $variant->product->title, 'requested' => $requested, 'available' => $current->stock_quantity, 'reason' => 'insufficient_stock'];
            } elseif ($requested > $current->purchase_limit) {
                $problems[] = ['product_variant_id' => $variant->id, 'title' => $variant->product->title, 'requested' => $requested, 'available' => $current->purchase_limit, 'reason' => 'over_purchase_limit'];
            }
        }

        if ($problems !== []) {
            throw new ConflictException('Some items in your cart are no longer available in the requested quantity. Please review your cart.', [
                'items' => $problems,
            ]);
        }
    }

    private function findByKey(User $user, string $key): ?Order
    {
        return $user->orders()->where('idempotency_key', $key)->first();
    }

    private function newOrderNumber(): string
    {
        do {
            $number = 'RS'.now()->format('ymd').'-'.Str::upper(Str::random(6));
        } while (Order::where('number', $number)->exists());

        return $number;
    }
}
