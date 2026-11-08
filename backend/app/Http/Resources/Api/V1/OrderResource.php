<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Order */
class OrderResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'number' => $this->number,
            'status' => $this->status->value,
            'payment_status' => $this->payment_status->value,
            'payment_method' => [
                'id' => $this->payment_method_id,
                'type' => $this->payment_method->value,
                'label' => $this->payment_method_label,
            ],
            'delivery_method' => $this->delivery_method->value,
            'currency' => $this->currency,
            'subtotal' => $this->subtotal,
            'discount_total' => $this->discount_total,
            'shipping_total' => $this->shipping_total,
            'grand_total' => $this->grand_total,
            'coupon_code' => $this->coupon_code,
            'shipping_address' => [
                'label' => $this->shipping_label,
                'recipient_name' => $this->shipping_recipient_name,
                'phone' => $this->shipping_phone,
                'line1' => $this->shipping_line1,
                'line2' => $this->shipping_line2,
                'city' => $this->shipping_city,
                'state' => $this->shipping_state,
                'postal_code' => $this->shipping_postal_code,
                'country_code' => $this->shipping_country_code,
            ],
            'note' => $this->note,
            'item_count' => (int) $this->items->sum('quantity'),
            'items' => OrderItemResource::collection($this->items),
            'placed_at' => $this->placed_at?->toIso8601ZuluString(),
            // When each tracking step happened (null until it has).
            'paid_at' => $this->paid_at?->toIso8601ZuluString(),
            'processing_at' => $this->processing_at?->toIso8601ZuluString(),
            'shipped_at' => $this->shipped_at?->toIso8601ZuluString(),
            'out_for_delivery_at' => $this->out_for_delivery_at?->toIso8601ZuluString(),
            'delivered_at' => $this->delivered_at?->toIso8601ZuluString(),
            'cancelled_at' => $this->cancelled_at?->toIso8601ZuluString(),
            'updated_at' => $this->updated_at?->toIso8601ZuluString(),
        ];
    }
}
