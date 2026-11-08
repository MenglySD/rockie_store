<?php

namespace App\Http\Requests\Api\V1;

use App\Enums\DeliveryMethod;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PlaceOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Totals are never accepted from the client; they are recalculated.
     *
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        $userId = $this->user()->id;

        return [
            'address_id' => ['required', 'integer', Rule::exists('addresses', 'id')->where('user_id', $userId)],
            'payment_method_id' => ['required', 'integer', Rule::exists('payment_methods', 'id')->where('user_id', $userId)],
            'delivery_method' => ['nullable', Rule::enum(DeliveryMethod::class)],
            'note' => ['nullable', 'string', 'max:500'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'address_id.required' => 'Please add or select a shipping address.',
            'address_id.exists' => 'Please add or select a shipping address.',
            'payment_method_id.required' => 'Please add or select a payment method.',
            'payment_method_id.exists' => 'Please add or select a payment method.',
        ];
    }
}
