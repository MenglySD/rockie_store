<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['email', 'otp_hash', 'attempts', 'expires_at', 'verified_at', 'reset_token_hash', 'reset_token_expires_at', 'used_at'])]
#[Hidden(['otp_hash', 'reset_token_hash'])]
class PasswordResetOtp extends Model
{
    protected function casts(): array
    {
        return [
            'attempts' => 'integer',
            'expires_at' => 'datetime',
            'verified_at' => 'datetime',
            'reset_token_expires_at' => 'datetime',
            'used_at' => 'datetime',
        ];
    }
}
