<?php

namespace Tests\Feature\Api;

use App\Models\Address;
use App\Models\PaymentMethod;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AddressAndPaymentMethodTest extends TestCase
{
    use RefreshDatabase;

    private array $address = [
        'label' => 'Home',
        'recipient_name' => 'Sam',
        'phone' => '+855 12 345 678',
        'line1' => '123 Street 271',
        'city' => 'Phnom Penh',
        'country_code' => 'kh',
    ];

    public function test_new_user_has_no_address_and_no_payment_method(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/addresses')->assertOk()->assertExactJson(['data' => []]);
        $this->getJson('/api/v1/payment-methods')->assertOk()->assertExactJson(['data' => []]);
    }

    public function test_first_address_is_not_made_default_automatically(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/addresses', $this->address)
            ->assertCreated()
            ->assertJsonPath('data.is_default', false)
            ->assertJsonPath('data.country_code', 'KH');
    }

    public function test_setting_default_address_unsets_the_others(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $first = $this->postJson('/api/v1/addresses', $this->address + ['is_default' => true])
            ->assertJsonPath('data.is_default', true)
            ->json('data.id');
        $second = $this->postJson('/api/v1/addresses', $this->address)
            ->assertJsonPath('data.is_default', false)
            ->json('data.id');

        $this->patchJson("/api/v1/addresses/{$second}", ['is_default' => true])
            ->assertOk()
            ->assertJsonPath('data.is_default', true);

        $this->assertFalse(Address::find($first)->is_default);
        $this->assertSame(1, $user->addresses()->where('is_default', true)->count());

        // Deleting the default does not promote another address.
        $this->deleteJson("/api/v1/addresses/{$second}")->assertNoContent();
        $this->assertSame(0, $user->addresses()->where('is_default', true)->count());
    }

    public function test_address_validation(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/addresses', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['recipient_name', 'phone', 'line1', 'city'])
            ->assertJsonMissingValidationErrors(['country_code']);
    }

    public function test_address_without_country_uses_the_store_default(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/addresses', [
            'label' => 'Home', 'recipient_name' => 'Sam', 'phone' => '+85512345678',
            'line1' => 'St 110', 'city' => 'Phnom Penh',
        ])->assertCreated()
            ->assertJsonPath('data.country_code', 'KH')
            ->assertJsonPath('data.is_default', false);
    }

    public function test_user_cannot_touch_another_users_address(): void
    {
        $other = Address::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/v1/addresses/{$other->id}")->assertForbidden();
        $this->patchJson("/api/v1/addresses/{$other->id}", ['city' => 'Hacked'])->assertForbidden();
        $this->deleteJson("/api/v1/addresses/{$other->id}")->assertForbidden();
        $this->assertDatabaseHas('addresses', ['id' => $other->id, 'city' => $other->city]);
    }

    public function test_payment_method_has_no_default_unless_requested(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $year = (int) now()->addYear()->format('Y');

        $first = $this->postJson('/api/v1/payment-methods', [
            'brand' => 'mastercard', 'last4' => '4444', 'exp_month' => 12, 'exp_year' => $year,
        ])->assertCreated()
            ->assertJsonPath('data.type', 'card')
            ->assertJsonPath('data.label', 'Mastercard •••• 4444')
            ->assertJsonPath('data.exp_month', 12)
            ->assertJsonPath('data.exp_year', $year)
            ->assertJsonPath('data.is_expired', false)
            ->assertJsonPath('data.is_default', false)
            ->json('data.id');

        $card = $this->postJson('/api/v1/payment-methods', [
            'type' => 'card', 'label' => 'Visa •••• 4242', 'brand' => 'visa', 'last4' => '4242',
            'exp_month' => 1, 'exp_year' => $year, 'is_default' => true,
        ])->assertCreated()
            ->assertJsonPath('data.is_default', true)
            ->assertJsonPath('data.last4', '4242')
            ->json('data.id');

        $this->patchJson("/api/v1/payment-methods/{$first}", ['is_default' => true])->assertOk();

        $this->assertTrue(PaymentMethod::find($first)->is_default);
        $this->assertFalse(PaymentMethod::find($card)->is_default);
    }

    public function test_only_unexpired_cards_can_be_added(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $lastMonth = now()->subMonthNoOverflow();

        $this->postJson('/api/v1/payment-methods', ['type' => 'cash_on_delivery', 'label' => 'Cash'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['type']);

        $this->postJson('/api/v1/payment-methods', ['last4' => '4242'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['exp_month', 'exp_year']);

        $this->postJson('/api/v1/payment-methods', [
            'last4' => '4242', 'exp_month' => $lastMonth->month, 'exp_year' => $lastMonth->year,
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['exp_month']);

        $this->postJson('/api/v1/payment-methods', [
            'last4' => '4242', 'exp_month' => now()->month, 'exp_year' => now()->year,
        ])->assertCreated();
    }

    public function test_full_card_number_and_cvv_are_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/payment-methods', [
            'type' => 'card', 'label' => 'Visa', 'last4' => '4242',
            'exp_month' => 12, 'exp_year' => (int) now()->addYear()->format('Y'),
            'card_number' => '4242424242424242', 'cvv' => '123',
        ])->assertUnprocessable()->assertJsonValidationErrors(['card_number', 'cvv']);

        $this->assertDatabaseCount('payment_methods', 0);
    }

    public function test_user_cannot_touch_another_users_payment_method(): void
    {
        $other = PaymentMethod::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->patchJson("/api/v1/payment-methods/{$other->id}", ['label' => 'Mine'])->assertForbidden();
        $this->deleteJson("/api/v1/payment-methods/{$other->id}")->assertForbidden();
    }
}
