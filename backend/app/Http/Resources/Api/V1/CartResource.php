<?php

namespace App\Http\Resources\Api\V1;

use App\Support\MediaUrl;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Wraps the array returned by CartService::summarize().
 */
class CartResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $summary = $this->resource;

        return [
            'id' => $summary['cart']->id,
            'items' => array_map(function (array $line) {
                $variant = $line['variant'];
                $product = $variant->product;

                return [
                    'id' => $line['item']->id,
                    'product_id' => $product->id,
                    'product_variant_id' => $variant->id,
                    'title' => $product->title,
                    'variant' => $variant->label(),
                    'color' => $variant->color,
                    'size' => $variant->size,
                    'sku' => $variant->sku,
                    'unit_price' => Money::format($line['unit']),
                    'original_price' => $product->original_price,
                    'quantity' => $line['item']->quantity,
                    'is_selected' => $line['selected'],
                    'line_total' => Money::format($line['total']),
                    'image_url' => MediaUrl::resolve($product->images->first()?->url),
                    'stock' => $variant->stock_quantity,
                    'purchase_limit' => $variant->purchase_limit,
                    // null, "unavailable", "insufficient_stock" or "over_purchase_limit"
                    'issue' => $line['issue'],
                ];
            }, $summary['lines']),
            // Every item (cart badge) and only the selected ones (checkout).
            'item_count' => array_sum(array_map(fn ($line) => $line['item']->quantity, $summary['lines'])),
            'selected_item_count' => array_sum(array_map(fn ($line) => $line['item']->quantity, $summary['selected_lines'])),
            'coupon' => $summary['coupon'] ? [
                'code' => $summary['coupon']->code,
                'title' => $summary['coupon']->title,
                'is_applicable' => $summary['coupon_error'] === null,
                'message' => $summary['coupon_error'],
            ] : null,
            'delivery_method' => $summary['delivery_method']->value,
            'subtotal' => Money::format($summary['subtotal']),
            'discount_total' => Money::format($summary['discount']),
            'shipping_total' => Money::format($summary['shipping']),
            'grand_total' => Money::format($summary['grand']),
            'currency' => $summary['currency'],
        ];
    }
}
