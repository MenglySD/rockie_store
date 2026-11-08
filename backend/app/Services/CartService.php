<?php

namespace App\Services;

use App\Enums\CouponType;
use App\Enums\DeliveryMethod;
use App\Exceptions\ConflictException;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Coupon;
use App\Models\ProductVariant;
use App\Models\User;
use App\Support\Money;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Server-side cart. Prices always come from the database; the client only
 * sends variant IDs and quantities.
 */
class CartService
{
    public function cartFor(User $user): Cart
    {
        return Cart::firstOrCreate(['user_id' => $user->id]);
    }

    public function addItem(User $user, int $variantId, int $quantity): Cart
    {
        return DB::transaction(function () use ($user, $variantId, $quantity) {
            $cart = $this->cartFor($user);
            $variant = ProductVariant::with('product')->findOrFail($variantId);

            $item = $cart->items()->where('product_variant_id', $variant->id)->lockForUpdate()->first();
            $newQuantity = ($item?->quantity ?? 0) + $quantity;

            $this->assertCanHold($variant, $newQuantity);

            // Adding (again) always selects the item.
            if ($item) {
                $item->update(['quantity' => $newQuantity, 'is_selected' => true]);
            } else {
                $cart->items()->create(['product_variant_id' => $variant->id, 'quantity' => $newQuantity, 'is_selected' => true]);
            }

            return $cart;
        });
    }

    /**
     * Change the quantity and/or whether the item is selected for checkout.
     */
    public function updateItem(CartItem $item, ?int $quantity, ?bool $selected): Cart
    {
        if ($quantity !== null) {
            $item->loadMissing('variant.product');
            $this->assertCanHold($item->variant, $quantity);
            $item->quantity = $quantity;
        }

        if ($selected !== null) {
            $item->is_selected = $selected;
        }

        $item->save();

        return $item->cart;
    }

    /**
     * Select or unselect every item ("Select all").
     */
    public function selectAll(User $user, bool $selected): Cart
    {
        $cart = $this->cartFor($user);
        $cart->items()->update(['is_selected' => $selected]);

        return $cart;
    }

    public function removeItem(CartItem $item): Cart
    {
        $cart = $item->cart;
        $item->delete();

        return $cart;
    }

    public function applyCoupon(User $user, string $code): Cart
    {
        $cart = $this->cartFor($user);
        $coupon = Coupon::where('code', Str::upper(trim($code)))->first();

        if (! $coupon || ! $coupon->isAvailable()) {
            throw ValidationException::withMessages(['code' => ['This coupon is invalid or has expired.']]);
        }

        $summary = $this->summarize($cart->setRelation('coupon', null));

        if ($summary['subtotal'] < Money::toCents($coupon->min_subtotal)) {
            throw ValidationException::withMessages([
                'code' => ["Spend at least {$coupon->min_subtotal} {$this->currency()} to use this coupon."],
            ]);
        }

        $cart->coupon()->associate($coupon)->save();

        return $cart;
    }

    public function removeCoupon(User $user): Cart
    {
        $cart = $this->cartFor($user);
        $cart->coupon()->dissociate()->save();

        return $cart;
    }

    /**
     * Calculate the canonical cart contents and totals (all amounts in cents).
     * Every item is listed; only selected items count towards the totals.
     *
     * @return array{
     *     cart: Cart,
     *     lines: list<array{item: CartItem, variant: ProductVariant, unit: int, total: int, issue: ?string, selected: bool}>,
     *     selected_lines: list<array{item: CartItem, variant: ProductVariant, unit: int, total: int, issue: ?string, selected: bool}>,
     *     subtotal: int, discount: int, shipping: int, grand: int,
     *     coupon: ?Coupon, coupon_error: ?string, delivery_method: DeliveryMethod, currency: string
     * }
     */
    public function summarize(Cart $cart, DeliveryMethod $delivery = DeliveryMethod::Standard): array
    {
        $cart->loadMissing(['items.variant.product.images', 'coupon']);

        $lines = [];
        $selectedLines = [];
        $subtotal = 0;

        foreach ($cart->items->sortBy('id') as $item) {
            $variant = $item->variant;
            $unit = Money::toCents($variant->product->price);
            $total = $unit * $item->quantity;

            $line = [
                'item' => $item,
                'variant' => $variant,
                'unit' => $unit,
                'total' => $total,
                'issue' => $this->lineIssue($variant, $item->quantity),
                'selected' => $item->is_selected,
            ];
            $lines[] = $line;

            if ($item->is_selected) {
                $selectedLines[] = $line;
                $subtotal += $total;
            }
        }

        $shipping = $selectedLines === [] ? 0 : $delivery->feeCents();
        $coupon = $cart->coupon;
        $couponError = $coupon ? $this->couponError($coupon, $subtotal) : null;
        $discount = $coupon && $couponError === null ? $this->discountFor($coupon, $subtotal, $shipping) : 0;

        return [
            'cart' => $cart,
            'lines' => $lines,
            'selected_lines' => $selectedLines,
            'subtotal' => $subtotal,
            'discount' => $discount,
            'shipping' => $shipping,
            'grand' => max(0, $subtotal + $shipping - $discount),
            'coupon' => $coupon,
            'coupon_error' => $couponError,
            'delivery_method' => $delivery,
            'currency' => $this->currency(),
        ];
    }

    /**
     * Why a coupon cannot be used on this subtotal, or null when it can.
     */
    public function couponError(Coupon $coupon, int $subtotal): ?string
    {
        if (! $coupon->isAvailable()) {
            return 'This coupon is no longer available.';
        }

        if ($subtotal < Money::toCents($coupon->min_subtotal)) {
            return "Spend at least {$coupon->min_subtotal} {$this->currency()} to use this coupon.";
        }

        return null;
    }

    /**
     * Discount in cents, never more than what it applies to.
     */
    public function discountFor(Coupon $coupon, int $subtotal, int $shipping): int
    {
        $value = Money::toCents($coupon->value);

        return match ($coupon->type) {
            CouponType::Percent => min($subtotal, (int) round($subtotal * $value / 10_000)),
            CouponType::Fixed => min($subtotal, $value),
            CouponType::FreeShipping => $shipping,
        };
    }

    public function currency(): string
    {
        return config('store.currency');
    }

    /**
     * @throws ValidationException when the purchase limit is exceeded (422)
     * @throws ConflictException when the product is unavailable or stock is short (409)
     */
    private function assertCanHold(ProductVariant $variant, int $quantity): void
    {
        if (! $variant->isPurchasable()) {
            throw new ConflictException('This product is no longer available.', [
                'product_variant_id' => $variant->id,
            ]);
        }

        if ($quantity > $variant->purchase_limit) {
            throw ValidationException::withMessages([
                'quantity' => ["You can buy at most {$variant->purchase_limit} of this item."],
            ]);
        }

        if ($quantity > $variant->stock_quantity) {
            throw new ConflictException("Only {$variant->stock_quantity} left in stock.", [
                'product_variant_id' => $variant->id,
                'requested' => $quantity,
                'available' => $variant->stock_quantity,
            ]);
        }
    }

    private function lineIssue(ProductVariant $variant, int $quantity): ?string
    {
        return match (true) {
            ! $variant->isPurchasable() => 'unavailable',
            $variant->stock_quantity < $quantity => 'insufficient_stock',
            $quantity > $variant->purchase_limit => 'over_purchase_limit',
            default => null,
        };
    }
}
