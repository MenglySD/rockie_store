<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Used for POST /addresses and PATCH /addresses/{address}; on PATCH every
 * field is optional and only the fields sent are changed.
 */
class AddressRequest extends FormRequest
{
    public function authorize(): bool
    {
        $address = $this->route('address');

        return $address === null || $this->user()->can('update', $address);
    }

    protected function prepareForValidation(): void
    {
        // The app only asks for name, phone, label, street and city.
        if ($this->isMethod('POST') && ! $this->filled('country_code')) {
            $this->merge(['country_code' => config('store.default_country_code')]);
        }

        if (is_string($this->country_code)) {
            $this->merge(['country_code' => strtoupper(trim($this->country_code))]);
        }
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        $required = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'label' => ['sometimes', 'nullable', 'string', 'max:50'],
            'recipient_name' => [$required, 'string', 'max:255'],
            'phone' => [$required, 'string', 'max:30', 'regex:/^\+?[0-9 ()\-]{6,30}$/'],
            'line1' => [$required, 'string', 'max:255'],
            'line2' => ['sometimes', 'nullable', 'string', 'max:255'],
            'city' => [$required, 'string', 'max:100'],
            'state' => ['sometimes', 'nullable', 'string', 'max:100'],
            'postal_code' => ['sometimes', 'nullable', 'string', 'max:20'],
            'country_code' => [$required, 'string', 'size:2', 'alpha'],
            'is_default' => ['sometimes', 'boolean'],
        ];
    }
}
