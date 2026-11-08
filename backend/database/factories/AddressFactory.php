<?php

namespace Database\Factories;

use App\Models\Address;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Address>
 */
class AddressFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'label' => 'Home',
            'recipient_name' => fake()->name(),
            'phone' => '+855 12 345 678',
            'line1' => fake()->streetAddress(),
            'line2' => null,
            'city' => 'Phnom Penh',
            'state' => null,
            'postal_code' => '12000',
            'country_code' => 'KH',
        ];
    }
}
