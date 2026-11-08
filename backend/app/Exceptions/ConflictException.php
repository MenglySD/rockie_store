<?php

namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;

/**
 * HTTP 409: the request was valid but the store state changed
 * (stock ran out, coupon expired, ...). The app should reload the cart.
 */
class ConflictException extends RuntimeException
{
    /**
     * @param  array<string, mixed>  $errors
     */
    public function __construct(string $message, public readonly array $errors = [])
    {
        parent::__construct($message);
    }

    public function render(): JsonResponse
    {
        $payload = ['message' => $this->getMessage()];

        if ($this->errors !== []) {
            $payload['errors'] = $this->errors;
        }

        return response()->json($payload, 409);
    }
}
