<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\ChangePasswordRequest;
use App\Http\Requests\Api\V1\UpdateAvatarRequest;
use App\Http\Requests\Api\V1\UpdateProfileRequest;
use App\Http\Resources\Api\V1\UserResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ProfileController extends Controller
{
    public function show(Request $request): UserResource
    {
        return new UserResource($request->user());
    }

    public function update(UpdateProfileRequest $request): UserResource
    {
        $user = $request->user();
        $user->update($request->safe()->only(['name', 'gender', 'phone', 'avatar_url']));

        return new UserResource($user);
    }

    /**
     * Upload a new profile photo (multipart field "avatar").
     */
    public function updateAvatar(UpdateAvatarRequest $request): UserResource
    {
        $user = $request->user();
        $path = $request->file('avatar')->store('avatars', 'public');

        $this->deleteStoredAvatar($user->avatar_url);
        $user->update(['avatar_url' => 'storage/'.$path]);

        return new UserResource($user);
    }

    public function destroyAvatar(Request $request): UserResource
    {
        $user = $request->user();

        $this->deleteStoredAvatar($user->avatar_url);
        $user->update(['avatar_url' => null]);

        return new UserResource($user);
    }

    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        $user = $request->user();
        $user->forceFill(['password' => Hash::make($request->string('password'))])->save();

        // Keep this device signed in, sign out every other device.
        $user->tokens()->whereKeyNot($user->currentAccessToken()->getKey())->delete();

        return response()->json(['message' => 'Your password has been changed.']);
    }

    /**
     * Removes an uploaded photo; external URLs (e.g. Google) are left alone.
     */
    private function deleteStoredAvatar(?string $avatarUrl): void
    {
        if ($avatarUrl !== null && Str::startsWith($avatarUrl, 'storage/avatars/')) {
            Storage::disk('public')->delete(Str::after($avatarUrl, 'storage/'));
        }
    }
}
