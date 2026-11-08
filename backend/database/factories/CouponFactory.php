<?php

namespace Database\Factories;

use App\Models\Coupon;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Coupon>
 */
class CouponFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'code' => Str::upper(Str::random(8)),
            'title' => '10% OFF',
            'description' => null,
            'type' => 'percent',
            'value' => '10.00',
            'min_subtotal' => '0.00',
            'starts_at' => null,
            'expires_at' => now()->addMonth(),
            'usage_limit' => null,
            'used_count' => 0,
            'is_active' => true,
        ];
    }
}
