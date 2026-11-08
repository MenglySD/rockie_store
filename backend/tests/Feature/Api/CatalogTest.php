<?php

namespace Tests\Feature\Api;

use App\Models\Banner;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CatalogTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // Seeds inside the test transaction (the in-memory DB is migrated once per run).
        $this->seed(DatabaseSeeder::class);
    }

    public function test_seeded_catalog_is_browsable(): void
    {
        $this->getJson('/api/v1/categories')->assertOk()->assertJsonCount(10, 'data');

        $this->getJson('/api/v1/products?per_page=50')
            ->assertOk()
            ->assertJsonCount(26, 'data')
            ->assertJsonStructure(['data' => [['id', 'title', 'price', 'original_price', 'rating', 'image_url', 'in_stock']], 'links', 'meta']);
    }

    public function test_banners_are_listed_in_order_and_hidden_when_inactive_or_expired(): void
    {
        $this->getJson('/api/v1/banners')
            ->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.image_url', url('storage/seed-images/banner/banner1.png'))
            ->assertJsonPath('data.2.image_url', url('storage/seed-images/banner/banner3.jpg'));

        Banner::where('sort_order', 1)->update(['is_active' => false]);
        Banner::where('sort_order', 2)->update(['ends_at' => now()->subMinute()]);

        $this->getJson('/api/v1/banners')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.sort_order', 3);
    }

    public function test_products_can_be_filtered_searched_and_sorted(): void
    {
        $jeans = $this->getJson('/api/v1/categories')->collect('data')->firstWhere('slug', 'jeans');

        $this->getJson("/api/v1/products?category_id={$jeans['id']}")
            ->assertOk()
            ->assertJsonCount(4, 'data');

        $categories = $this->getJson('/api/v1/categories')->collect('data')->keyBy('slug');
        $women = $categories->only(['womens-clothing', 'womens-shoes']);

        $this->getJson('/api/v1/products?per_page=50&category_ids='.$women->pluck('id')->implode(','))
            ->assertOk()
            ->assertJsonCount($women->sum('products_count'), 'data');

        $this->getJson('/api/v1/products?category_ids=1,999')->assertUnprocessable();

        $this->getJson('/api/v1/products?q=loafers')->assertOk()->assertJsonCount(4, 'data');

        $prices = $this->getJson('/api/v1/products?sort=price_asc&min_price=30&max_price=35&per_page=50')
            ->assertOk()
            ->collect('data')
            ->pluck('price');

        $this->assertNotEmpty($prices);
        $this->assertSame($prices->sort()->values()->all(), $prices->all());
        $this->assertTrue($prices->every(fn ($p) => (float) $p >= 30 && (float) $p <= 35));
    }

    public function test_product_detail_has_images_variants_and_reviews(): void
    {
        $this->getJson('/api/v1/products/1')
            ->assertOk()
            ->assertJsonPath('data.price', '25.00')
            ->assertJsonPath('data.original_price', '33.33')
            ->assertJsonPath('data.sold_count', 70)
            ->assertJsonPath('data.rating', 4.5)
            ->assertJsonPath('data.review_count', 214)
            ->assertJsonPath('data.images.0', url('storage/seed-images/product/loafers1.jpg'))
            ->assertJsonPath('data.variants.0.sku', 'RS-0001-BLACK-39')
            ->assertJsonCount(12, 'data.variants')
            ->assertJsonCount(3, 'data.review_summary.latest');

        $this->getJson('/api/v1/products/1/reviews')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Banana')
            ->assertJsonCount(3, 'data.0.images');

        $this->getJson('/api/v1/products/9999')->assertNotFound();
    }
}
