<?php

namespace App\Models;

use App\Enums\DeliveryMethod;
use App\Enums\OrderStatus;
use App\Enums\PaymentMethodType;
use App\Enums\PaymentStatus;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable([
    'number', 'user_id', 'idempotency_key', 'status', 'currency',
    'subtotal', 'discount_total', 'shipping_total', 'grand_total',
    'coupon_id', 'coupon_code', 'delivery_method',
    'payment_method_id', 'payment_method', 'payment_method_label', 'payment_status',
    'address_id', 'shipping_label', 'shipping_recipient_name', 'shipping_phone',
    'shipping_line1', 'shipping_line2', 'shipping_city', 'shipping_state',
    'shipping_postal_code', 'shipping_country_code',
    'note', 'placed_at',
])]
class Order extends Model
{
    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,
            'payment_status' => PaymentStatus::class,
            'payment_method' => PaymentMethodType::class,
            'delivery_method' => DeliveryMethod::class,
            'subtotal' => 'decimal:2',
            'discount_total' => 'decimal:2',
            'shipping_total' => 'decimal:2',
            'grand_total' => 'decimal:2',
            'placed_at' => 'datetime',
            'paid_at' => 'datetime',
            'processing_at' => 'datetime',
            'shipped_at' => 'datetime',
            'out_for_delivery_at' => 'datetime',
            'delivered_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class)->orderBy('id');
    }
}
