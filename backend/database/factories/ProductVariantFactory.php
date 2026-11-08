<?php

namespace Database\Factories;

use App\Models\Product;
use App\Models\ProductVariant;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<ProductVariant>
 */
class ProductVariantFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'product_id' => Product::factory(),
            'sku' => 'TEST-'.Str::upper(Str::random(10)),
            'color' => 'Black',
            'size' => fake()->unique()->numerify('##'),
            'stock_quantity' => 20,
            'purchase_limit' => 10,
            'is_active' => true,
        ];
    }

    public function stock(int $quantity): static
    {
        return $this->state(fn () => ['stock_quantity' => $quantity]);
    }
}
