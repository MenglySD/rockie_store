<?php

namespace App\Models;

use App\Models\Concerns\HasExclusiveDefault;
use Database\Factories\AddressFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['label', 'recipient_name', 'phone', 'line1', 'line2', 'city', 'state', 'postal_code', 'country_code'])]
class Address extends Model
{
    /** @use HasFactory<AddressFactory> */
    use HasExclusiveDefault, HasFactory;

    protected function casts(): array
    {
        return [
            'is_default' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
