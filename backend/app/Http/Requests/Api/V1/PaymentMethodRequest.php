<?php

namespace App\Http\Requests\Api\V1;

use App\Enums\PaymentMethodType;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/**
 * Used for POST /payment-methods and PATCH /payment-methods/{paymentMethod}.
 *
 * New payment methods are cards only. The app reads the card number and
 * security code on the device and sends only the brand, last 4 digits and
 * expiry; the full number and CVV are rejected here.
 */
class PaymentMethodRequest extends FormRequest
{
    public function authorize(): bool
    {
        $paymentMethod = $this->route('paymentMethod');

        return $paymentMethod === null || $this->user()->can('update', $paymentMethod);
    }

    protected function prepareForValidation(): void
    {
        if ($this->isMethod('POST') && ! $this->has('type')) {
            $this->merge(['type' => PaymentMethodType::Card->value]);
        }
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        $creating = $this->isMethod('POST');
        $type = $creating ? $this->input('type') : $this->route('paymentMethod')?->type?->value;
        $isCard = $type === PaymentMethodType::Card->value;
        $year = (int) now()->format('Y');

        return [
            // Existing cash-on-delivery methods still work, but new ones are cards.
            'type' => $creating
                ? ['required', Rule::in([PaymentMethodType::Card->value])]
                : ['prohibited'],
            'label' => ['sometimes', 'nullable', 'string', 'max:100'],
            'brand' => $isCard
                ? ['sometimes', 'nullable', 'string', 'max:30']
                : ['prohibited'],
            'last4' => $isCard
                ? [$creating ? 'required' : 'sometimes', 'digits:4']
                : ['prohibited'],
            'exp_month' => $isCard
                ? [$creating ? 'required' : 'sometimes', 'integer', 'between:1,12']
                : ['prohibited'],
            'exp_year' => $isCard
                ? [$creating ? 'required' : 'sometimes', 'integer', 'between:'.$year.','.($year + 20)]
                : ['prohibited'],
            'provider' => ['sometimes', 'nullable', 'string', 'max:50'],
            'provider_reference' => ['sometimes', 'nullable', 'string', 'max:255'],
            'is_default' => ['sometimes', 'boolean'],

            // Never accept raw card data.
            'card_number' => ['prohibited'],
            'number' => ['prohibited'],
            'pan' => ['prohibited'],
            'cvv' => ['prohibited'],
            'cvc' => ['prohibited'],
        ];
    }

    /**
     * The card must not have expired (month and year checked together,
     * falling back to the saved values on PATCH).
     *
     * @return array<int, callable>
     */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($validator->errors()->hasAny(['exp_month', 'exp_year'])) {
                    return;
                }

                $saved = $this->route('paymentMethod');
                $month = $this->input('exp_month', $saved?->exp_month);
                $year = $this->input('exp_year', $saved?->exp_year);

                if ($month === null || $year === null) {
                    return;
                }

                $expiresAfter = now()->setDate((int) $year, (int) $month, 1)->endOfMonth();

                if ($expiresAfter->isPast()) {
                    $validator->errors()->add('exp_month', 'This card has expired.');
                }
            },
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        $message = 'Full card numbers and security codes must never be sent to this API.';

        return [
            'type.in' => 'Only cards can be added.',
            'type.prohibited' => 'The payment method type cannot be changed.',
            'card_number.prohibited' => $message,
            'number.prohibited' => $message,
            'pan.prohibited' => $message,
            'cvv.prohibited' => $message,
            'cvc.prohibited' => $message,
            'brand.prohibited' => 'Only card payment methods have a brand.',
            'last4.prohibited' => 'Only card payment methods have last4.',
            'exp_month.prohibited' => 'Only card payment methods have an expiry date.',
            'exp_year.prohibited' => 'Only card payment methods have an expiry date.',
        ];
    }
}
