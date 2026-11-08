<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\FirebaseLoginRequest;
use App\Http\Requests\Api\V1\LoginRequest;
use App\Http\Requests\Api\V1\RegisterRequest;
use App\Http\Resources\Api\V1\UserResource;
use App\Models\User;
use App\Services\AuthService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(private readonly AuthService $auth) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $result = $this->auth->register($request->validated(), $request->input('device_name'));

        return $this->tokenResponse($result['token'], $result['user'], 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $result = $this->auth->login($request->string('email'), $request->string('password'), $request->input('device_name'));

        return $this->tokenResponse($result['token'], $result['user']);
    }

    public function firebase(FirebaseLoginRequest $request): JsonResponse
    {
        $result = $this->auth->loginWithFirebase($request->string('id_token'), $request->input('device_name'));

        return $this->tokenResponse($result['token'], $result['user'], $result['created'] ? 201 : 200);
    }

    public function logout(Request $request): JsonResponse
    {
        $this->auth->logout($request->user());

        return response()->json(['message' => 'Logged out.']);
    }

    private function tokenResponse(string $token, User $user, int $status = 200): JsonResponse
    {
        return response()->json([
            'data' => [
                'token' => $token,
                'token_type' => 'Bearer',
                'user' => new UserResource($user),
            ],
        ], $status);
    }
}
