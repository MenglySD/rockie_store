<?php

namespace App\Models;

use Database\Factories\ProductVariantFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['product_id', 'sku', 'color', 'size', 'stock_quantity', 'purchase_limit', 'is_active'])]
class ProductVariant extends Model
{
    /** @use HasFactory<ProductVariantFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'stock_quantity' => 'integer',
            'purchase_limit' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    /**
     * Whether this variant and its product can currently be bought.
     */
    public function isPurchasable(): bool
    {
        return $this->is_active && $this->product !== null && $this->product->is_active;
    }

    /**
     * Human readable label, e.g. "Black / 42".
     */
    public function label(): string
    {
        return collect([$this->color, $this->size])->filter()->implode(' / ');
    }
}
