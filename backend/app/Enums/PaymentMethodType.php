<?php

namespace App\Enums;

enum PaymentMethodType: string
{
    case CashOnDelivery = 'cash_on_delivery';
    case Card = 'card';
}
