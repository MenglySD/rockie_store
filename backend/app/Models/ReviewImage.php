<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['review_id', 'url'])]
class ReviewImage extends Model
{
    public function review(): BelongsTo
    {
        return $this->belongsTo(Review::class);
    }
}
