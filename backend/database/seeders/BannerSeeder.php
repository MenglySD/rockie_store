<?php

namespace Database\Seeders;

use App\Models\Banner;
use Illuminate\Database\Seeder;

/**
 * Home slider from the Flutter app's assets/images/banner/
 * (copied to storage/app/public/seed-images/banner/).
 */
class BannerSeeder extends Seeder
{
    public function run(): void
    {
        $banners = [
            ['title' => 'Banner 1', 'image_url' => 'storage/seed-images/banner/banner1.png'],
            ['title' => 'Banner 2', 'image_url' => 'storage/seed-images/banner/banner2.png'],
            ['title' => 'Banner 3', 'image_url' => 'storage/seed-images/banner/banner3.jpg'],
        ];

        foreach ($banners as $index => $banner) {
            Banner::updateOrCreate(['image_url' => $banner['image_url']], $banner + [
                'is_active' => true,
                'sort_order' => $index + 1,
            ]);
        }
    }
}
