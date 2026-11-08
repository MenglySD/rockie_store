<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Seeds categories, products, images, variants and reviews from
 * database/seeders/data/products.json (converted from the Flutter app).
 *
 * Images: copy the Flutter folder assets/images/ to
 * storage/app/public/seed-images/ and run `php artisan storage:link`.
 * "assets/images/product/pants.png" is stored as
 * "storage/seed-images/product/pants.png" and served as an absolute URL
 * via asset() by the API Resources.
 */
class ProductSeeder extends Seeder
{
    public function run(): void
    {
        $data = json_decode(
            file_get_contents(database_path('seeders/data/products.json')),
            true,
            flags: JSON_THROW_ON_ERROR,
        );

        // Unguarded so the explicit product IDs from the JSON file are kept.
        Model::unguarded(fn () => DB::transaction(function () use ($data) {
            $categories = $this->seedCategories($data['categories']);

            foreach ($data['products'] as $row) {
                $this->seedProduct($row, $categories);
            }
        }));

        $this->syncSequences(['categories', 'products']);
    }

    /**
     * @return array<string, int> category id by slug
     */
    private function seedCategories(array $rows): array
    {
        $ids = [];

        foreach ($rows as $row) {
            $category = Category::updateOrCreate(['slug' => $row['slug']], [
                'name' => $row['name'],
                'image_url' => $this->imagePath($row['image'] ?? null),
                'is_active' => true,
                'sort_order' => $row['sort_order'] ?? 0,
            ]);

            $ids[$row['slug']] = $category->id;
        }

        return $ids;
    }

    /**
     * @param  array<string, int>  $categories
     */
    private function seedProduct(array $row, array $categories): void
    {
        $primary = $categories[$row['category']]
            ?? throw new \RuntimeException("Unknown category [{$row['category']}] for product {$row['id']}.");

        $product = Product::updateOrCreate(['id' => $row['id']], [
            'category_id' => $primary,
            'title' => trim($row['title']),
            'description' => $row['description'] ?? null,
            'price' => $row['price'],
            'original_price' => $row['original_price'] ?? $row['price'],
            'sold_count' => (int) preg_replace('/\D/', '', (string) ($row['sold'] ?? '0')),
            'rating_avg' => $row['rating'] ?? 0,
            'review_count' => $row['review_count'] ?? 0,
            'is_active' => true,
        ]);

        $extra = array_map(fn ($slug) => $categories[$slug], $row['extra_categories'] ?? []);
        $product->categories()->sync(array_unique([$primary, ...$extra]));

        $product->images()->delete();
        foreach ($row['images'] as $index => $image) {
            if ($path = $this->imagePath($image)) {
                $product->images()->create(['url' => $path, 'sort_order' => $index]);
            }
        }

        $this->seedVariants($product, $row);
        $this->seedReviews($product, $row['reviews'] ?? []);
    }

    private function seedVariants(Product $product, array $row): void
    {
        $colors = $row['colors'] ?: [null];
        $sizes = $row['sizes'] ?: [null];

        foreach ($colors as $color) {
            foreach ($sizes as $size) {
                $sku = collect([
                    'RS',
                    str_pad((string) $product->id, 4, '0', STR_PAD_LEFT),
                    $color ? Str::upper(Str::slug($color, '')) : null,
                    $size ? Str::upper(Str::slug($size, '')) : null,
                ])->filter()->implode('-');

                $product->variants()->updateOrCreate(['sku' => $sku], [
                    'color' => $color,
                    'size' => $size,
                    'stock_quantity' => $row['stock_per_variant'] ?? 20,
                    'purchase_limit' => $row['purchase_limit'] ?? 10,
                    'is_active' => true,
                ]);
            }
        }
    }

    private function seedReviews(Product $product, array $reviews): void
    {
        // Seeded reviews have no user; real reviews are added through the API.
        $product->reviews()->whereNull('user_id')->delete();

        foreach ($reviews as $row) {
            $createdAt = now()->subDays($row['days_ago'] ?? 0);

            $review = $product->reviews()->create([
                'reviewer_name' => $row['name'],
                'reviewer_avatar' => $row['avatar'] ?? null,
                'rating' => $row['rating'],
                'body' => $row['text'],
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);

            foreach ($row['images'] ?? [] as $image) {
                if ($path = $this->imagePath($image)) {
                    $review->images()->create(['url' => $path]);
                }
            }
        }
    }

    /**
     * Map "assets/images/x/y.png" to "storage/seed-images/x/y.png", warning
     * (but continuing) when the file has not been copied yet.
     */
    private function imagePath(?string $flutterPath): ?string
    {
        if (! $flutterPath) {
            return null;
        }

        $relative = Str::after($flutterPath, 'assets/images/');

        if (! Storage::disk('public')->exists('seed-images/'.$relative)) {
            $message = "Seed image missing: storage/app/public/seed-images/{$relative}";
            Log::warning($message);
            $this->command?->warn($message);
        }

        return 'storage/seed-images/'.$relative;
    }

    /**
     * Products are inserted with explicit IDs; move PostgreSQL sequences past them.
     *
     * @param  list<string>  $tables
     */
    private function syncSequences(array $tables): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            return;
        }

        foreach ($tables as $table) {
            DB::statement("SELECT setval(pg_get_serial_sequence('{$table}', 'id'), COALESCE((SELECT MAX(id) FROM {$table}), 0) + 1, false)");
        }
    }
}
