<?php

namespace App\Enums;

enum PaymentStatus: string
{
    // Cash on delivery: collected by the courier.
    case Unpaid = 'unpaid';
    // Card: waiting for confirmation from the payment provider's webhook.
    case Pending = 'pending';
    case Paid = 'paid';
    case Failed = 'failed';
    case Refunded = 'refunded';
}
