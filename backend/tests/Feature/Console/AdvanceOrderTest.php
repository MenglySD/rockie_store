<?php

namespace Tests\Feature\Console;

use App\Models\Address;
use App\Models\PaymentMethod;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdvanceOrderTest extends TestCase
{
    use RefreshDatabase;

    public function test_card_order_moves_through_pay_ship_and_deliver(): void
    {
        $user = User::factory()->create(['email' => 'buyer@example.com']);
        Sanctum::actingAs($user);
        $number = $this->placeCardOrder($user);

        $this->getJson('/api/v1/orders')->assertJsonPath('data.0.payment_status', 'pending');

        $this->artisan('order:advance', ['--user' => 'buyer@example.com'])->assertSuccessful();
        $this->getJson('/api/v1/orders')
            ->assertJsonPath('data.0.status', 'processing')
            ->assertJsonPath('data.0.payment_status', 'paid');

        $this->artisan('order:advance')->assertSuccessful();
        $this->getJson('/api/v1/orders')->assertJsonPath('data.0.status', 'shipped');

        $this->artisan('order:advance', ['number' => $number])->assertSuccessful();
        $this->getJson('/api/v1/orders')->assertJsonPath('data.0.status', 'out_for_delivery');

        $this->artisan('order:advance', ['number' => $number])->assertSuccessful();
        $order = $this->getJson('/api/v1/orders')->assertJsonPath('data.0.status', 'delivered')->json('data.0');

        // Every step has its time.
        foreach (['placed_at', 'paid_at', 'processing_at', 'shipped_at', 'out_for_delivery_at', 'delivered_at'] as $field) {
            $this->assertNotNull($order[$field], "{$field} should be set");
        }
        $this->assertNull($order['cancelled_at']);

        // Nothing left to do, and steps cannot be skipped.
        $this->artisan('order:advance')->assertFailed();
        $this->artisan('order:advance', ['--to' => 'ship'])->assertFailed();

        $types = $user->appNotifications()->pluck('type')->all();
        $this->assertSame(['order_placed', 'order_paid', 'order_shipped', 'order_out_for_delivery', 'order_delivered'], $types);
    }

    public function test_editing_the_orders_table_directly_sends_notifications_and_keeps_the_order(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $number = $this->placeCardOrder($user);
        $order = fn () => DB::table('orders')->where('number', $number);

        // Skipping ahead, going back, unknown values and shipping unpaid are refused.
        foreach ([
            ['status' => 'delivered'],
            ['status' => 'shipped'],
            ['status' => 'Shipped'],
            ['payment_status' => 'done'],
        ] as $bad) {
            try {
                $order()->update($bad);
                $this->fail('Expected the database to refuse '.json_encode($bad));
            } catch (QueryException) {
                // expected
            }
        }

        $order()->update(['payment_status' => 'paid', 'status' => 'processing']);
        $order()->update(['status' => 'shipped']);
        $this->getJson('/api/v1/orders')->assertJsonPath('data.0.status', 'shipped');

        try {
            $order()->update(['status' => 'processing']);
            $this->fail('Expected the database to refuse going back.');
        } catch (QueryException) {
            // expected
        }

        $order()->update(['status' => 'out_for_delivery']);
        $order()->update(['status' => 'delivered']);
        $this->assertNotNull($order()->value('out_for_delivery_at'));
        $this->assertNotNull($order()->value('delivered_at'));

        $this->getJson('/api/v1/notifications')
            ->assertJsonPath('data.0.type', 'order_delivered')
            ->assertJsonPath('data.0.title', 'Order delivered')
            ->assertJsonPath('data.0.data.order_id', $order()->value('id'));
        $this->assertSame(
            ['order_placed', 'order_paid', 'order_shipped', 'order_out_for_delivery', 'order_delivered'],
            $user->appNotifications()->orderBy('id')->pluck('type')->all(),
        );
        $this->assertStringContainsString($number, $user->appNotifications()->where('type', 'order_shipped')->value('body'));
    }

    public function test_unpaid_card_order_cannot_be_shipped(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $number = $this->placeCardOrder($user);

        $this->artisan('order:advance', ['number' => $number, '--to' => 'ship'])->assertFailed();
        $this->artisan('order:advance', ['number' => 'RS-NOPE'])->assertFailed();
    }

    private function placeCardOrder(User $user): string
    {
        $product = Product::factory()->create(['price' => '25.00', 'original_price' => '25.00']);
        $variant = ProductVariant::factory()->for($product)->create(['stock_quantity' => 10]);
        $address = Address::factory()->for($user)->create();
        $card = PaymentMethod::factory()->for($user)->create([
            'type' => 'card', 'label' => 'Visa •••• 4242', 'brand' => 'visa', 'last4' => '4242',
            'exp_month' => 12, 'exp_year' => (int) now()->addYear()->format('Y'),
        ]);

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 1]);

        return $this->postJson('/api/v1/orders', ['address_id' => $address->id, 'payment_method_id' => $card->id])
            ->assertCreated()
            ->json('data.number');
    }
}
