<?php

namespace Database\Factories;

use App\Models\PaymentMethod;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<PaymentMethod>
 */
class PaymentMethodFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'type' => 'cash_on_delivery',
            'label' => 'Cash on delivery',
        ];
    }

    public function card(): static
    {
        return $this->state(fn () => [
            'type' => 'card',
            'label' => 'Visa •••• 4242',
            'brand' => 'visa',
            'last4' => '4242',
            'provider' => 'stripe',
            'provider_reference' => 'pm_test_123',
        ]);
    }
}
