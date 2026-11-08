<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class StoreReviewRequest extends FormRequest
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
            'rating' => ['required', 'integer', 'between:1,5'],
            'body' => ['required', 'string', 'min:3', 'max:2000'],
            // Up to 5 photos, sent as multipart files "images[]".
            'images' => ['nullable', 'array', 'max:5'],
            'images.*' => ['file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'images.max' => 'You can add up to 5 photos.',
            'images.*.image' => 'Each photo must be a JPG, PNG or WebP image.',
            'images.*.mimes' => 'Each photo must be a JPG, PNG or WebP image.',
            'images.*.max' => 'Each photo must be 5 MB or smaller.',
        ];
    }
}
