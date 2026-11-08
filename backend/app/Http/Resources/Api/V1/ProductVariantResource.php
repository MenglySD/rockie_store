<?php

namespace App\Http\Resources\Api\V1;

use App\Models\ProductVariant;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin ProductVariant */
class ProductVariantResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'sku' => $this->sku,
            'color' => $this->color,
            'size' => $this->size,
            'stock' => $this->stock_quantity,
            'purchase_limit' => $this->purchase_limit,
            'in_stock' => $this->stock_quantity > 0,
        ];
    }
}
