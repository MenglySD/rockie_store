<?php

namespace App\Enums;

use App\Support\Money;

enum DeliveryMethod: string
{
    case Standard = 'standard';
    case Express = 'express';

    /**
     * Shipping fee in cents.
     */
    public function feeCents(): int
    {
        return Money::toCents(config('store.shipping.'.$this->value));
    }
}
