<?php

namespace App\Services;

use App\Mail\PasswordResetOtpMail;
use App\Models\PasswordResetOtp;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Password reset by e-mailed 6-digit code:
 * forgot-password -> verify-otp (returns reset_token) -> reset-password.
 */
class OtpService
{
    /**
     * Send a code if an account exists. Callers must always return the same
     * response so the endpoint cannot be used to discover accounts.
     */
    public function sendResetCode(string $email): void
    {
        $email = Str::lower($email);
        $user = User::where('email', $email)->first();

        if (! $user) {
            return;
        }

        $otp = str_pad((string) random_int(0, 999_999), 6, '0', STR_PAD_LEFT);

        DB::transaction(function () use ($email, $otp) {
            // Only the newest code is valid.
            PasswordResetOtp::where('email', $email)->whereNull('used_at')->delete();

            PasswordResetOtp::create([
                'email' => $email,
                'otp_hash' => Hash::make($otp),
                'attempts' => 0,
                'expires_at' => now()->addMinutes(config('store.otp.expires_minutes')),
            ]);
        });

        Mail::to($user->email)->send(new PasswordResetOtpMail($otp, $user->name, config('store.otp.expires_minutes')));
    }

    /**
     * Check the code and return a single-use reset token.
     */
    public function verify(string $email, string $otp): string
    {
        $email = Str::lower($email);

        // Returns null on a wrong code so the attempt counter is committed
        // before the error is thrown (throwing inside would roll it back).
        $resetToken = DB::transaction(function () use ($email, $otp) {
            $record = PasswordResetOtp::where('email', $email)
                ->whereNull('used_at')
                ->whereNull('verified_at')
                ->latest('id')
                ->lockForUpdate()
                ->first();

            if (! $record || $record->expires_at->isPast()) {
                throw $this->invalid('otp', 'This code is invalid or has expired. Please request a new one.');
            }

            if ($record->attempts >= config('store.otp.max_attempts')) {
                throw $this->invalid('otp', 'Too many incorrect attempts. Please request a new code.');
            }

            if (! Hash::check($otp, $record->otp_hash)) {
                $record->increment('attempts');

                return null;
            }

            $resetToken = Str::random(64);

            $record->forceFill([
                'verified_at' => now(),
                'reset_token_hash' => hash('sha256', $resetToken),
                'reset_token_expires_at' => now()->addMinutes(config('store.otp.reset_token_minutes')),
            ])->save();

            return $resetToken;
        });

        return $resetToken ?? throw $this->invalid('otp', 'The code you entered is incorrect.');
    }

    /**
     * Set the new password, consume the token and log out every device.
     */
    public function resetPassword(string $email, string $resetToken, string $password): void
    {
        $email = Str::lower($email);

        DB::transaction(function () use ($email, $resetToken, $password) {
            $record = PasswordResetOtp::where('email', $email)
                ->where('reset_token_hash', hash('sha256', $resetToken))
                ->whereNotNull('verified_at')
                ->whereNull('used_at')
                ->lockForUpdate()
                ->first();

            $user = User::where('email', $email)->first();

            $expired = ! $record?->reset_token_expires_at || $record->reset_token_expires_at->isPast();

            if (! $record || ! $user || $expired) {
                throw $this->invalid('reset_token', 'This reset link is invalid or has expired. Please request a new code.');
            }

            $user->forceFill([
                'password' => Hash::make($password),
                'remember_token' => Str::random(60),
            ])->save();

            $record->forceFill(['used_at' => now()])->save();

            $user->tokens()->delete();
        });
    }

    private function invalid(string $field, string $message): ValidationException
    {
        return ValidationException::withMessages([$field => [$message]]);
    }
}
