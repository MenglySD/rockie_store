<?php

namespace App\Http\Requests\Api\V1;

use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;

class ProductIndexRequest extends FormRequest
{
    public const SORTS = ['newest', 'price_asc', 'price_desc', 'popular', 'rating'];

    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        // ?category_ids=1,2 → [1, 2]
        if (is_string($this->category_ids)) {
            $this->merge(['category_ids' => array_values(array_filter(explode(',', $this->category_ids), 'strlen'))]);
        }
    }

    /**
     * @return array<string, ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'category_ids' => ['nullable', 'array', 'max:20'],
            'category_ids.*' => ['integer', 'distinct', 'exists:categories,id'],
            'q' => ['nullable', 'string', 'max:100'],
            'sort' => ['nullable', 'in:'.implode(',', self::SORTS)],
            'min_price' => ['nullable', 'decimal:0,2', 'min:0'],
            'max_price' => ['nullable', 'decimal:0,2', 'min:0', 'gte:min_price'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ];
    }
}
