<?php

namespace App\Models;

use App\Enums\PaymentMethodType;
use App\Models\Concerns\HasExclusiveDefault;
use Database\Factories\PaymentMethodFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A saved way to pay. Only display data and a provider token reference are
 * stored; the full card number and CVV never reach this server.
 */
#[Fillable(['type', 'label', 'brand', 'last4', 'exp_month', 'exp_year', 'provider', 'provider_reference'])]
class PaymentMethod extends Model
{
    /** @use HasFactory<PaymentMethodFactory> */
    use HasExclusiveDefault, HasFactory;

    protected function casts(): array
    {
        return [
            'type' => PaymentMethodType::class,
            'is_default' => 'boolean',
            'exp_month' => 'integer',
            'exp_year' => 'integer',
        ];
    }

    /**
     * "Visa •••• 4242", or "Cash on delivery".
     */
    public function defaultLabel(): string
    {
        if ($this->type === PaymentMethodType::CashOnDelivery) {
            return 'Cash on delivery';
        }

        return ucfirst($this->brand ?: 'card').' •••• '.$this->last4;
    }

    public function isExpired(): bool
    {
        if ($this->exp_month === null || $this->exp_year === null) {
            return false;
        }

        return now()->setDate($this->exp_year, $this->exp_month, 1)->endOfMonth()->isPast();
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
