<?php

namespace Database\Seeders;

use App\Models\Coupon;
use Illuminate\Database\Seeder;

/**
 * Sample coupons matching the Flutter app's lib/data/coupons.dart.
 */
class CouponSeeder extends Seeder
{
    public function run(): void
    {
        $coupons = [
            [
                'code' => 'WELCOME10',
                'title' => '10% OFF',
                'description' => 'A little something for your next order.',
                'type' => 'percent',
                'value' => '10.00',
                'min_subtotal' => '25.00',
                'expires_at' => '2026-12-31 23:59:59',
            ],
            [
                'code' => 'SAVE5',
                'title' => '$5 OFF',
                'description' => 'Save $5 on your next purchase.',
                'type' => 'fixed',
                'value' => '5.00',
                'min_subtotal' => '30.00',
                'expires_at' => '2026-11-30 23:59:59',
            ],
            [
                'code' => 'FREESHIP',
                'title' => 'FREE SHIPPING',
                'description' => 'Delivery is on us for your next order.',
                'type' => 'free_shipping',
                'value' => '0.00',
                'min_subtotal' => '0.00',
                'expires_at' => '2026-10-31 23:59:59',
            ],
        ];

        foreach ($coupons as $coupon) {
            Coupon::updateOrCreate(['code' => $coupon['code']], $coupon + [
                'starts_at' => null,
                'usage_limit' => null,
                'is_active' => true,
            ]);
        }
    }
}
