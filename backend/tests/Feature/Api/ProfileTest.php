<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_upload_and_remove_a_profile_photo(): void
    {
        Storage::fake('public');
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $first = $this->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->image('me.jpg', 300, 300)], ['Accept' => 'application/json'])
            ->assertOk()
            ->json('data.avatar_url');
        $firstPath = $user->refresh()->avatar_url;

        $this->assertStringStartsWith(url('storage/avatars/'), $first);
        Storage::disk('public')->assertExists(str($firstPath)->after('storage/')->value());

        // A new photo replaces the old file.
        $this->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->image('new.png')], ['Accept' => 'application/json'])
            ->assertOk();
        Storage::disk('public')->assertMissing(str($firstPath)->after('storage/')->value());

        $this->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->create('cv.pdf', 10, 'application/pdf')], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['avatar']);

        $this->deleteJson('/api/v1/me/avatar')->assertOk()->assertJsonPath('data.avatar_url', null);
        $this->assertSame([], Storage::disk('public')->allFiles('avatars'));
    }

    public function test_user_can_edit_profile(): void
    {
        $user = User::factory()->create(['email' => 'sam@example.com']);
        Sanctum::actingAs($user);

        $this->patchJson('/api/v1/me', [
            'name' => 'Sam Rockie',
            'gender' => 'prefer_not_to_say',
            'phone' => '+855 12 345 678',
            'avatar_url' => 'https://example.com/avatar.png',
        ])->assertOk()
            ->assertJsonPath('data.name', 'Sam Rockie')
            ->assertJsonPath('data.gender', 'prefer_not_to_say')
            ->assertJsonPath('data.phone', '+855 12 345 678')
            ->assertJsonPath('data.avatar_url', 'https://example.com/avatar.png');

        // gender can be cleared.
        $this->patchJson('/api/v1/me', ['gender' => null])->assertOk()->assertJsonPath('data.gender', null);
    }

    public function test_email_cannot_be_changed_and_gender_is_validated(): void
    {
        Sanctum::actingAs(User::factory()->create(['email' => 'sam@example.com']));

        $this->patchJson('/api/v1/me', ['email' => 'new@example.com', 'gender' => 'robot'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email', 'gender']);

        $this->assertDatabaseHas('users', ['email' => 'sam@example.com']);
    }

    public function test_user_can_change_password(): void
    {
        $user = User::factory()->create(['password' => 'old-password']);
        $token = $user->createToken('this-device')->plainTextToken;
        $user->createToken('other-device');

        $this->withToken($token)->postJson('/api/v1/me/change-password', [
            'current_password' => 'wrong',
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('current_password');

        $this->withToken($token)->postJson('/api/v1/me/change-password', [
            'current_password' => 'old-password',
            'password' => 'new-password',
            'password_confirmation' => 'new-password',
        ])->assertOk();

        $this->assertTrue(Hash::check('new-password', $user->fresh()->password));
        $this->assertSame(1, $user->tokens()->count(), 'Other devices are signed out.');
    }
}
