<?php

namespace App\Services;

use App\Exceptions\ConflictException;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthService
{
    /** Firebase sign-in providers accepted by POST /auth/firebase. */
    private const SOCIAL_PROVIDERS = ['google.com', 'facebook.com'];

    public function __construct(private readonly FirebaseTokenVerifier $firebase) {}

    /**
     * @param  array{name: string, email: string, password: string, gender?: ?string}  $data
     * @return array{token: string, user: User}
     */
    public function register(array $data, ?string $deviceName = null): array
    {
        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'gender' => $data['gender'] ?? null,
        ]);

        return ['token' => $this->issueToken($user, $deviceName), 'user' => $user];
    }

    /**
     * @return array{token: string, user: User}
     *
     * @throws ValidationException with a generic message on any failure
     */
    public function login(string $email, string $password, ?string $deviceName = null): array
    {
        $user = User::where('email', Str::lower($email))->first();

        // Social-only users have no password, so Hash::check is skipped for them.
        if (! $user || ! $user->hasPassword() || ! Hash::check($password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => [__('auth.failed')],
            ]);
        }

        return ['token' => $this->issueToken($user, $deviceName), 'user' => $user];
    }

    /**
     * Exchange a verified Firebase ID token (Google/Facebook only) for a Sanctum token.
     *
     * @return array{token: string, user: User, created: bool}
     */
    public function loginWithFirebase(string $idToken, ?string $deviceName = null): array
    {
        $claims = $this->firebase->verify($idToken);

        if (! in_array($claims['provider'], self::SOCIAL_PROVIDERS, true)) {
            throw ValidationException::withMessages([
                'id_token' => ['Only Google and Facebook sign-in use this endpoint. Use /auth/login for email and password.'],
            ]);
        }

        [$user, $created] = DB::transaction(fn () => $this->findOrCreateFirebaseUser($claims));

        return ['token' => $this->issueToken($user, $deviceName), 'user' => $user, 'created' => $created];
    }

    public function logout(User $user): void
    {
        $user->currentAccessToken()?->delete();
    }

    public function issueToken(User $user, ?string $deviceName = null): string
    {
        return $user->createToken($deviceName ?: 'flutter-app')->plainTextToken;
    }

    /**
     * @param  array{uid: string, email: ?string, email_verified: bool, name: ?string, picture: ?string}  $claims
     * @return array{0: User, 1: bool}
     */
    private function findOrCreateFirebaseUser(array $claims): array
    {
        $user = User::where('firebase_uid', $claims['uid'])->lockForUpdate()->first();

        if ($user) {
            return [$user, false];
        }

        $email = $claims['email'] ? Str::lower($claims['email']) : null;
        $existing = $email ? User::where('email', $email)->lockForUpdate()->first() : null;

        if ($existing) {
            // Only link when Firebase has verified the address and the account
            // is not already linked to a different Firebase user.
            if (! $claims['email_verified'] || ($existing->firebase_uid && $existing->firebase_uid !== $claims['uid'])) {
                throw new ConflictException('An account with this email already exists. Sign in with your email and password.');
            }

            $existing->forceFill([
                'firebase_uid' => $claims['uid'],
                'email_verified_at' => $existing->email_verified_at ?? now(),
                'avatar_url' => $existing->avatar_url ?? $claims['picture'],
            ])->save();

            return [$existing, false];
        }

        $user = User::create([
            'name' => $claims['name'] ?: ($email ? Str::before($email, '@') : 'Rockie Shopper'),
            'email' => $email,
            'email_verified_at' => $email && $claims['email_verified'] ? now() : null,
            'firebase_uid' => $claims['uid'],
            'avatar_url' => $claims['picture'],
            'password' => null,
        ]);

        return [$user, true];
    }
}
