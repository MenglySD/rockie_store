<?php

namespace Tests\Feature\Api;

use App\Models\User;
use App\Services\FirebaseTokenVerifier;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_and_receives_a_token(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Sam',
            'email' => 'Sam@Example.com',
            'password' => 'secret-password',
            'password_confirmation' => 'secret-password',
            'gender' => 'female',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['data' => ['token', 'token_type', 'user' => ['id', 'name', 'email', 'gender']]])
            ->assertJsonPath('data.user.email', 'sam@example.com')
            ->assertJsonPath('data.user.gender', 'female');

        $user = User::where('email', 'sam@example.com')->first();
        $this->assertTrue(Hash::check('secret-password', $user->password));
        $this->assertSame(0, $user->addresses()->count());
        $this->assertSame(0, $user->paymentMethods()->count());

        $this->withToken($response->json('data.token'))
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.email', 'sam@example.com');
    }

    public function test_register_validates_input(): void
    {
        User::factory()->create(['email' => 'taken@example.com']);

        $this->postJson('/api/v1/auth/register', [
            'name' => '',
            'email' => 'taken@example.com',
            'password' => 'short',
            'password_confirmation' => 'different',
            'gender' => 'robot',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors(['name', 'email', 'password', 'gender']);
    }

    public function test_user_can_login(): void
    {
        User::factory()->create(['email' => 'sam@example.com', 'password' => 'secret-password']);

        $this->postJson('/api/v1/auth/login', ['email' => 'sam@example.com', 'password' => 'secret-password'])
            ->assertOk()
            ->assertJsonStructure(['data' => ['token', 'user' => ['id', 'email']]]);
    }

    public function test_wrong_credentials_return_generic_422(): void
    {
        User::factory()->create(['email' => 'sam@example.com', 'password' => 'secret-password']);

        $wrongPassword = $this->postJson('/api/v1/auth/login', ['email' => 'sam@example.com', 'password' => 'nope']);
        $unknownEmail = $this->postJson('/api/v1/auth/login', ['email' => 'ghost@example.com', 'password' => 'nope']);

        $wrongPassword->assertUnprocessable()->assertJsonValidationErrors('email');
        $unknownEmail->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->assertSame($wrongPassword->json('errors.email'), $unknownEmail->json('errors.email'));
    }

    public function test_login_is_rate_limited(): void
    {
        User::factory()->create(['email' => 'sam@example.com', 'password' => 'secret-password']);

        foreach (range(1, 5) as $ignored) {
            $this->postJson('/api/v1/auth/login', ['email' => 'sam@example.com', 'password' => 'nope'])->assertUnprocessable();
        }

        $this->postJson('/api/v1/auth/login', ['email' => 'sam@example.com', 'password' => 'secret-password'])
            ->assertTooManyRequests();
    }

    public function test_logout_revokes_only_the_current_token_and_user_can_login_again(): void
    {
        $user = User::factory()->create(['email' => 'sam@example.com', 'password' => 'secret-password']);
        $phoneToken = $user->createToken('phone')->plainTextToken;

        $token = $this->postJson('/api/v1/auth/login', ['email' => 'sam@example.com', 'password' => 'secret-password'])
            ->json('data.token');

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertOk();
        $this->app['auth']->forgetGuards();

        $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();
        $this->app['auth']->forgetGuards();

        // The other device stays signed in.
        $this->withToken($phoneToken)->getJson('/api/v1/me')->assertOk();
        $this->app['auth']->forgetGuards();

        // Same email and password still work.
        $newToken = $this->postJson('/api/v1/auth/login', ['email' => 'sam@example.com', 'password' => 'secret-password'])
            ->assertOk()
            ->json('data.token');

        $this->withToken($newToken)->getJson('/api/v1/me')->assertOk();
    }

    public function test_protected_routes_return_401_without_token(): void
    {
        $this->getJson('/api/v1/me')->assertUnauthorized()->assertJson(['message' => 'Unauthenticated.']);
    }

    public function test_firebase_login_creates_user_from_verified_token(): void
    {
        $this->fakeFirebase([
            'uid' => 'firebase-uid-1',
            'email' => 'social@example.com',
            'email_verified' => true,
            'name' => 'Social User',
            'picture' => 'https://example.com/a.png',
            'provider' => 'google.com',
        ]);

        $this->postJson('/api/v1/auth/firebase', ['id_token' => 'valid-token', 'uid' => 'attacker-uid'])
            ->assertCreated()
            ->assertJsonPath('data.user.email', 'social@example.com')
            ->assertJsonPath('data.user.has_password', false);

        $this->assertDatabaseHas('users', ['email' => 'social@example.com', 'firebase_uid' => 'firebase-uid-1', 'password' => null]);
        $this->assertDatabaseMissing('users', ['firebase_uid' => 'attacker-uid']);
    }

    public function test_firebase_login_links_existing_account_by_verified_email(): void
    {
        $user = User::factory()->create(['email' => 'sam@example.com']);

        $this->fakeFirebase([
            'uid' => 'firebase-uid-2', 'email' => 'sam@example.com', 'email_verified' => true,
            'name' => 'Sam', 'picture' => null, 'provider' => 'facebook.com',
        ]);

        $this->postJson('/api/v1/auth/firebase', ['id_token' => 'valid-token'])
            ->assertOk()
            ->assertJsonPath('data.user.id', $user->id);

        $this->assertSame('firebase-uid-2', $user->fresh()->firebase_uid);
    }

    public function test_firebase_login_rejects_email_password_provider(): void
    {
        $this->fakeFirebase([
            'uid' => 'firebase-uid-3', 'email' => 'x@example.com', 'email_verified' => true,
            'name' => null, 'picture' => null, 'provider' => 'password',
        ]);

        $this->postJson('/api/v1/auth/firebase', ['id_token' => 'valid-token'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('id_token');
    }

    public function test_firebase_login_rejects_invalid_token(): void
    {
        $verifier = $this->mock(FirebaseTokenVerifier::class);
        $verifier->shouldReceive('verify')->andThrow(new AuthenticationException('Invalid or expired Firebase token.'));

        $this->postJson('/api/v1/auth/firebase', ['id_token' => 'forged'])
            ->assertUnauthorized()
            ->assertJson(['message' => 'Invalid or expired Firebase token.']);
    }

    private function fakeFirebase(array $claims): void
    {
        $verifier = $this->mock(FirebaseTokenVerifier::class);
        $verifier->shouldReceive('verify')->with('valid-token')->andReturn($claims);
    }
}
