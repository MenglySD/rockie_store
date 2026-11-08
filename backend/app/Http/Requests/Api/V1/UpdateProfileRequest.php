<?php

namespace App\Http\Requests\Api\V1;

use App\Enums\Gender;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'gender' => ['sometimes', 'nullable', Rule::enum(Gender::class)],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30', 'regex:/^\+?[0-9 ()\-]{6,30}$/'],
            'avatar_url' => ['sometimes', 'nullable', 'url:http,https', 'max:2048'],
            // Email changes are not supported in this version.
            'email' => ['prohibited'],
            'password' => ['prohibited'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'email.prohibited' => 'The email address cannot be changed.',
            'password.prohibited' => 'Use /me/change-password to change your password.',
        ];
    }
}
