<?php

namespace Tests\Feature\Api;

use App\Models\Address;
use App\Models\Coupon;
use App\Models\PaymentMethod;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CartAndOrderTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->user = User::factory()->create();
        Sanctum::actingAs($this->user);
    }

    public function test_add_to_cart_uses_server_prices(): void
    {
        $variant = $this->variant(price: '25.00', stock: 10);

        $this->postJson('/api/v1/cart/items', [
            'product_variant_id' => $variant->id,
            'quantity' => 2,
            'price' => '0.01', // ignored
        ])->assertCreated()
            ->assertJsonPath('data.items.0.product_variant_id', $variant->id)
            ->assertJsonPath('data.items.0.unit_price', '25.00')
            ->assertJsonPath('data.items.0.quantity', 2)
            ->assertJsonPath('data.items.0.line_total', '50.00')
            ->assertJsonPath('data.subtotal', '50.00')
            ->assertJsonPath('data.shipping_total', '1.49')
            ->assertJsonPath('data.grand_total', '51.49')
            ->assertJsonPath('data.currency', 'USD');

        // Adding the same variant again merges the line.
        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 1])
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.quantity', 3);
    }

    public function test_cart_enforces_stock_and_purchase_limit(): void
    {
        $variant = $this->variant(stock: 3, limit: 5);
        $limited = $this->variant(stock: 50, limit: 2);

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 4])
            ->assertConflict()
            ->assertJsonPath('errors.available', 3);

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $limited->id, 'quantity' => 3])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('quantity');
    }

    public function test_user_cannot_change_another_users_cart_item(): void
    {
        $variant = $this->variant();
        $other = User::factory()->create();
        $item = $other->cart()->create()->items()->create(['product_variant_id' => $variant->id, 'quantity' => 1]);

        $this->patchJson("/api/v1/cart/items/{$item->id}", ['quantity' => 5])->assertForbidden();
        $this->deleteJson("/api/v1/cart/items/{$item->id}")->assertForbidden();
    }

    public function test_user_can_remove_a_cart_item(): void
    {
        $shoes = $this->variant(price: '25.00');
        $shirt = $this->variant(price: '10.00');

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $shoes->id, 'quantity' => 1]);
        $items = $this->postJson('/api/v1/cart/items', ['product_variant_id' => $shirt->id, 'quantity' => 2])->json('data.items');

        $this->deleteJson("/api/v1/cart/items/{$items[0]['id']}")
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.product_variant_id', $shirt->id)
            ->assertJsonPath('data.item_count', 2)
            ->assertJsonPath('data.subtotal', '20.00');

        $this->getJson('/api/v1/cart')->assertJsonCount(1, 'data.items');
    }

    public function test_coupon_can_be_applied_and_removed(): void
    {
        $variant = $this->variant(price: '30.00');
        Coupon::factory()->create(['code' => 'WELCOME10', 'type' => 'percent', 'value' => '10.00', 'min_subtotal' => '25.00']);

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 1]);

        $this->postJson('/api/v1/cart/coupon', ['code' => 'welcome10'])
            ->assertOk()
            ->assertJsonPath('data.coupon.code', 'WELCOME10')
            ->assertJsonPath('data.discount_total', '3.00')
            ->assertJsonPath('data.grand_total', '28.49');

        $this->deleteJson('/api/v1/cart/coupon')
            ->assertOk()
            ->assertJsonPath('data.coupon', null)
            ->assertJsonPath('data.discount_total', '0.00');

        $this->postJson('/api/v1/cart/coupon', ['code' => 'NOPE'])->assertUnprocessable();
    }

    public function test_order_requires_own_address_and_payment_method(): void
    {
        $variant = $this->variant();
        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 1]);

        $this->postJson('/api/v1/orders', [])
            ->assertUnprocessable()
            ->assertJsonPath('errors.address_id.0', 'Please add or select a shipping address.')
            ->assertJsonPath('errors.payment_method_id.0', 'Please add or select a payment method.');

        // Someone else's address/payment method is treated as missing.
        $this->postJson('/api/v1/orders', [
            'address_id' => Address::factory()->create()->id,
            'payment_method_id' => PaymentMethod::factory()->create()->id,
        ])->assertUnprocessable()->assertJsonValidationErrors(['address_id', 'payment_method_id']);
    }

    public function test_totals_and_checkout_use_only_selected_items(): void
    {
        $shoes = $this->variant(price: '25.00', stock: 10);
        $shirt = $this->variant(price: '10.00', stock: 10);
        $address = Address::factory()->for($this->user)->create();
        $payment = PaymentMethod::factory()->for($this->user)->create();

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $shoes->id, 'quantity' => 2]);
        $cart = $this->postJson('/api/v1/cart/items', ['product_variant_id' => $shirt->id, 'quantity' => 1])
            ->assertJsonPath('data.items.0.is_selected', true)
            ->assertJsonPath('data.items.1.is_selected', true)
            ->assertJsonPath('data.subtotal', '60.00')
            ->json('data');
        $shirtItem = $cart['items'][1]['id'];

        // Unselect the shirt: totals follow, the item stays in the cart.
        $this->patchJson("/api/v1/cart/items/{$shirtItem}", ['is_selected' => false])
            ->assertOk()
            ->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.items.1.is_selected', false)
            ->assertJsonPath('data.item_count', 3)
            ->assertJsonPath('data.selected_item_count', 2)
            ->assertJsonPath('data.subtotal', '50.00')
            ->assertJsonPath('data.grand_total', '51.49');

        // Nothing selected: no shipping, and checkout is refused.
        $this->patchJson('/api/v1/cart/selection', ['is_selected' => false])
            ->assertJsonPath('data.subtotal', '0.00')
            ->assertJsonPath('data.shipping_total', '0.00')
            ->assertJsonPath('data.grand_total', '0.00');
        $this->postJson('/api/v1/orders', ['address_id' => $address->id, 'payment_method_id' => $payment->id])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['cart']);

        // Order only the shoes; the shirt stays in the cart.
        $this->patchJson('/api/v1/cart/selection', ['is_selected' => true]);
        $this->patchJson("/api/v1/cart/items/{$shirtItem}", ['is_selected' => false]);

        $this->postJson('/api/v1/orders', ['address_id' => $address->id, 'payment_method_id' => $payment->id])
            ->assertCreated()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.subtotal', '50.00');

        $this->getJson('/api/v1/cart')
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.items.0.product_variant_id', $shirt->id);
        $this->assertSame(10, $shirt->fresh()->stock_quantity);
        $this->assertSame(8, $shoes->fresh()->stock_quantity);
    }

    public function test_user_can_place_an_order(): void
    {
        $variant = $this->variant(price: '25.00', stock: 10);
        $address = Address::factory()->for($this->user)->create(['city' => 'Phnom Penh']);
        $payment = PaymentMethod::factory()->for($this->user)->create();
        Coupon::factory()->create(['code' => 'SAVE5', 'type' => 'fixed', 'value' => '5.00', 'min_subtotal' => '30.00']);

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 2]);
        $this->postJson('/api/v1/cart/coupon', ['code' => 'SAVE5'])->assertOk();

        $response = $this->withHeader('Idempotency-Key', 'order-attempt-1')->postJson('/api/v1/orders', [
            'address_id' => $address->id,
            'payment_method_id' => $payment->id,
            'delivery_method' => 'express',
            'grand_total' => '0.01', // ignored
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.payment_status', 'unpaid')
            ->assertJsonPath('data.payment_method.type', 'cash_on_delivery')
            ->assertJsonPath('data.subtotal', '50.00')
            ->assertJsonPath('data.discount_total', '5.00')
            ->assertJsonPath('data.shipping_total', '2.49')
            ->assertJsonPath('data.grand_total', '47.49')
            ->assertJsonPath('data.coupon_code', 'SAVE5')
            ->assertJsonPath('data.shipping_address.city', 'Phnom Penh')
            ->assertJsonPath('data.items.0.sku', $variant->sku)
            ->assertJsonPath('data.items.0.quantity', 2);

        $orderId = $response->json('data.id');

        $this->assertSame(8, $variant->fresh()->stock_quantity);
        $this->assertSame(2, $variant->product->fresh()->sold_count);
        $this->assertSame(1, Coupon::where('code', 'SAVE5')->value('used_count'));
        $this->getJson('/api/v1/cart')->assertJsonCount(0, 'data.items')->assertJsonPath('data.coupon', null);

        // Address snapshot survives later edits.
        $address->update(['city' => 'Siem Reap']);
        $this->getJson("/api/v1/orders/{$orderId}")->assertOk()->assertJsonPath('data.shipping_address.city', 'Phnom Penh');

        // Retrying with the same Idempotency-Key returns the same order.
        $this->withHeader('Idempotency-Key', 'order-attempt-1')->postJson('/api/v1/orders', [
            'address_id' => $address->id,
            'payment_method_id' => $payment->id,
        ])->assertOk()->assertJsonPath('data.id', $orderId);

        $this->assertSame(1, $this->user->orders()->count());
        $this->getJson('/api/v1/orders')->assertOk()->assertJsonCount(1, 'data')->assertJsonStructure(['data', 'links', 'meta']);
        $this->getJson('/api/v1/notifications')->assertOk()->assertJsonPath('data.0.type', 'order_placed');
    }

    public function test_order_returns_409_when_stock_ran_out(): void
    {
        $variant = $this->variant(stock: 5);
        $address = Address::factory()->for($this->user)->create();
        $payment = PaymentMethod::factory()->for($this->user)->create();

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 3])->assertCreated();

        // Someone else bought most of the stock meanwhile.
        $variant->update(['stock_quantity' => 1]);

        $this->postJson('/api/v1/orders', ['address_id' => $address->id, 'payment_method_id' => $payment->id])
            ->assertConflict()
            ->assertJsonPath('errors.items.0.product_variant_id', $variant->id)
            ->assertJsonPath('errors.items.0.requested', 3)
            ->assertJsonPath('errors.items.0.available', 1)
            ->assertJsonPath('errors.items.0.reason', 'insufficient_stock');

        // Nothing changed: no order, stock untouched, cart kept.
        $this->assertSame(0, $this->user->orders()->count());
        $this->assertSame(1, $variant->fresh()->stock_quantity);
        $this->getJson('/api/v1/cart')->assertJsonCount(1, 'data.items');
    }

    public function test_order_returns_409_when_coupon_is_no_longer_valid(): void
    {
        $variant = $this->variant(price: '30.00');
        $address = Address::factory()->for($this->user)->create();
        $payment = PaymentMethod::factory()->for($this->user)->create();
        $coupon = Coupon::factory()->create(['code' => 'FLASH']);

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 1]);
        $this->postJson('/api/v1/cart/coupon', ['code' => 'FLASH'])->assertOk();

        $coupon->update(['expires_at' => now()->subMinute()]);

        $this->postJson('/api/v1/orders', ['address_id' => $address->id, 'payment_method_id' => $payment->id])
            ->assertConflict();
        $this->assertSame(0, $this->user->orders()->count());
    }

    public function test_user_cannot_view_another_users_order(): void
    {
        $other = User::factory()->create();
        $variant = $this->variant();
        Sanctum::actingAs($other);
        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 1]);
        $orderId = $this->postJson('/api/v1/orders', [
            'address_id' => Address::factory()->for($other)->create()->id,
            'payment_method_id' => PaymentMethod::factory()->for($other)->create()->id,
        ])->assertCreated()->json('data.id');

        Sanctum::actingAs($this->user);
        $this->getJson("/api/v1/orders/{$orderId}")->assertForbidden();
        $this->getJson('/api/v1/orders/999999')->assertNotFound()->assertJson(['message' => 'Resource not found.']);
    }

    private function variant(string $price = '25.00', int $stock = 20, int $limit = 10): ProductVariant
    {
        $product = Product::factory()->create(['price' => $price, 'original_price' => $price]);

        return ProductVariant::factory()->for($product)->create([
            'stock_quantity' => $stock,
            'purchase_limit' => $limit,
        ]);
    }
}
