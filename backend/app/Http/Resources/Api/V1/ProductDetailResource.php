<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Product;
use App\Support\MediaUrl;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Product */
class ProductDetailResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $activeVariants = $this->variants->where('is_active', true)->values();

        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'category' => new CategoryResource($this->category),
            'price' => $this->price,
            'original_price' => $this->original_price,
            'discount_percent' => $this->discountPercent(),
            'currency' => config('store.currency'),
            'sold_count' => $this->sold_count,
            'sold_label' => ProductResource::soldLabel($this->sold_count),
            'rating' => round((float) $this->rating_avg, 1),
            'review_count' => $this->review_count,
            'images' => $this->images->map(fn ($image) => MediaUrl::resolve($image->url))->values(),
            'colors' => $activeVariants->pluck('color')->filter()->unique()->values(),
            'sizes' => $activeVariants->pluck('size')->filter()->unique()->values(),
            'variants' => ProductVariantResource::collection($activeVariants),
            'purchase_limit' => (int) $activeVariants->min('purchase_limit'),
            'in_stock' => $activeVariants->sum('stock_quantity') > 0,
            'review_summary' => [
                'rating' => round((float) $this->rating_avg, 1),
                'review_count' => $this->review_count,
                'latest' => ReviewResource::collection($this->whenLoaded('reviews')),
            ],
        ];
    }
}
