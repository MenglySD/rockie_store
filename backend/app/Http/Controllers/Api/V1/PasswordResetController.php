<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ForgotPasswordRequest;
use App\Http\Requests\Api\V1\ResetPasswordRequest;
use App\Http\Requests\Api\V1\VerifyOtpRequest;
use App\Services\OtpService;
use Illuminate\Http\JsonResponse;

class PasswordResetController extends Controller
{
    public function __construct(private readonly OtpService $otp) {}

    public function forgot(ForgotPasswordRequest $request): JsonResponse
    {
        $this->otp->sendResetCode($request->string('email'));

        // Identical response whether or not the account exists.
        return response()->json([
            'message' => 'If an account exists for this email, we have sent a 6-digit code to it.',
        ]);
    }

    public function verify(VerifyOtpRequest $request): JsonResponse
    {
        $resetToken = $this->otp->verify($request->string('email'), $request->string('otp'));

        return response()->json([
            'message' => 'Code verified.',
            'data' => [
                'reset_token' => $resetToken,
                'expires_in' => config('store.otp.reset_token_minutes') * 60,
            ],
        ]);
    }

    public function reset(ResetPasswordRequest $request): JsonResponse
    {
        $this->otp->resetPassword($request->string('email'), $request->string('reset_token'), $request->string('password'));

        return response()->json([
            'message' => 'Your password has been reset. Please log in with your new password.',
        ]);
    }
}
