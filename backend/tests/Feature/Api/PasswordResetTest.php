<?php

namespace Tests\Feature\Api;

use App\Mail\PasswordResetOtpMail;
use App\Models\PasswordResetOtp;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_full_otp_reset_flow(): void
    {
        Mail::fake();
        $user = User::factory()->create(['email' => 'sam@example.com', 'password' => 'old-password']);
        $existingToken = $user->createToken('old-device')->plainTextToken;

        // 1. Request a code.
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'sam@example.com'])->assertOk();

        $otp = null;
        Mail::assertSent(PasswordResetOtpMail::class, function (PasswordResetOtpMail $mail) use (&$otp) {
            $otp = $mail->otp;

            return $mail->hasTo('sam@example.com');
        });
        $this->assertMatchesRegularExpression('/^\d{6}$/', $otp);

        // Stored hashed, never in plain text.
        $record = PasswordResetOtp::where('email', 'sam@example.com')->first();
        $this->assertNotSame($otp, $record->otp_hash);
        $this->assertTrue(Hash::check($otp, $record->otp_hash));

        // 2. Verify the code.
        $resetToken = $this->postJson('/api/v1/auth/verify-otp', ['email' => 'sam@example.com', 'otp' => $otp])
            ->assertOk()
            ->json('data.reset_token');

        // The same code cannot be verified twice.
        $this->postJson('/api/v1/auth/verify-otp', ['email' => 'sam@example.com', 'otp' => $otp])
            ->assertUnprocessable();

        // 3. Reset the password.
        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'sam@example.com',
            'reset_token' => $resetToken,
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertOk();

        $this->assertNotNull($record->fresh()->used_at);
        $this->assertSame(0, $user->tokens()->count(), 'All devices are logged out.');

        // The reset token is single-use.
        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'sam@example.com',
            'reset_token' => $resetToken,
            'password' => 'another-password',
            'password_confirmation' => 'another-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('reset_token');

        // 4. Old token, old password fail; new password works.
        $this->withToken($existingToken)->getJson('/api/v1/me')->assertUnauthorized();
        $this->app['auth']->forgetGuards();

        $this->postJson('/api/v1/auth/login', ['email' => 'sam@example.com', 'password' => 'old-password'])
            ->assertUnprocessable();
        $this->postJson('/api/v1/auth/login', ['email' => 'sam@example.com', 'password' => 'new-password'])
            ->assertOk();
    }

    public function test_unknown_email_gets_same_response_and_no_mail(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'sam@example.com']);

        $known = $this->postJson('/api/v1/auth/forgot-password', ['email' => 'sam@example.com']);
        $unknown = $this->postJson('/api/v1/auth/forgot-password', ['email' => 'ghost@example.com']);

        $known->assertOk();
        $unknown->assertOk();
        $this->assertSame($known->json(), $unknown->json());
        Mail::assertSentCount(1);
    }

    public function test_forgot_password_is_limited_to_one_request_per_minute(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'sam@example.com']);

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'sam@example.com'])->assertOk();
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'sam@example.com'])->assertTooManyRequests();
    }

    public function test_otp_is_locked_after_five_wrong_attempts(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'sam@example.com']);
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'sam@example.com']);

        $otp = null;
        Mail::assertSent(PasswordResetOtpMail::class, function ($mail) use (&$otp) {
            $otp = $mail->otp;

            return true;
        });
        $wrong = $otp === '000000' ? '111111' : '000000';

        foreach (range(1, 5) as $ignored) {
            $this->postJson('/api/v1/auth/verify-otp', ['email' => 'sam@example.com', 'otp' => $wrong])
                ->assertUnprocessable();
        }

        // Even the right code is now rejected.
        $this->postJson('/api/v1/auth/verify-otp', ['email' => 'sam@example.com', 'otp' => $otp])
            ->assertUnprocessable()
            ->assertJsonPath('errors.otp.0', 'Too many incorrect attempts. Please request a new code.');
    }

    public function test_expired_otp_is_rejected(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'sam@example.com']);
        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'sam@example.com']);

        $otp = null;
        Mail::assertSent(PasswordResetOtpMail::class, function ($mail) use (&$otp) {
            $otp = $mail->otp;

            return true;
        });

        $this->travel(11)->minutes();

        $this->postJson('/api/v1/auth/verify-otp', ['email' => 'sam@example.com', 'otp' => $otp])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('otp');
    }
}
