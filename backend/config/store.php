<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Store Currency
    |--------------------------------------------------------------------------
    |
    | Every price, cart and order uses this single currency.
    |
    */

    'currency' => env('STORE_CURRENCY', 'USD'),

    /*
    |--------------------------------------------------------------------------
    | Default Country
    |--------------------------------------------------------------------------
    |
    | Used for new addresses that are sent without a country_code.
    |
    */

    'default_country_code' => env('STORE_COUNTRY_CODE', 'KH'),

    /*
    |--------------------------------------------------------------------------
    | Shipping Fees
    |--------------------------------------------------------------------------
    |
    | Flat fee per delivery method, as decimal strings. Matches the Flutter
    | checkout screen (standard $1.49, express +$1.00).
    |
    */

    'shipping' => [
        'standard' => env('STORE_SHIPPING_STANDARD', '1.49'),
        'express' => env('STORE_SHIPPING_EXPRESS', '2.49'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Password Reset OTP
    |--------------------------------------------------------------------------
    */

    'otp' => [
        'expires_minutes' => 10,
        'max_attempts' => 5,
        'reset_token_minutes' => 15,
    ],

];
