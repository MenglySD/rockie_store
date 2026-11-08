<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Product;
use App\Support\MediaUrl;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Product card for list screens (home, category, search).
 *
 * @mixin Product
 */
class ProductResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'category_id' => $this->category_id,
            'title' => $this->title,
            'price' => $this->price,
            'original_price' => $this->original_price,
            'discount_percent' => $this->discountPercent(),
            'sold_count' => $this->sold_count,
            'sold_label' => self::soldLabel($this->sold_count),
            'rating' => round((float) $this->rating_avg, 1),
            'review_count' => $this->review_count,
            'image_url' => MediaUrl::resolve($this->images->first()?->url),
            'in_stock' => (int) ($this->total_stock ?? $this->variants->where('is_active', true)->sum('stock_quantity')) > 0,
        ];
    }

    /**
     * Display string like the Flutter app's "70+" / "1.2k+".
     */
    public static function soldLabel(int $count): string
    {
        return match (true) {
            $count >= 1000 => rtrim(rtrim(number_format($count / 1000, 1), '0'), '.').'k+',
            $count > 0 => $count.'+',
            default => '0',
        };
    }
}
