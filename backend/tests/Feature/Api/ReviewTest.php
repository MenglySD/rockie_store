<?php

namespace Tests\Feature\Api;

use App\Models\Address;
use App\Models\PaymentMethod;
use App\Models\Product;
use App\Models\ProductVariant;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReviewTest extends TestCase
{
    use RefreshDatabase;

    public function test_buyer_can_review_with_up_to_five_photos(): void
    {
        Storage::fake('public');
        $product = $this->orderedProduct();

        // Six photos is one too many; nothing is stored.
        $this->post("/api/v1/products/{$product->id}/reviews", [
            'rating' => 5,
            'body' => 'Great shoes',
            'images' => array_map(fn ($i) => UploadedFile::fake()->image("p{$i}.jpg"), range(1, 6)),
        ], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['images']);
        $this->assertSame([], Storage::disk('public')->allFiles('reviews'));

        $review = $this->post("/api/v1/products/{$product->id}/reviews", [
            'rating' => 4,
            'body' => 'Comfortable and smart',
            'images' => [UploadedFile::fake()->image('a.jpg'), UploadedFile::fake()->image('b.png')],
        ], ['Accept' => 'application/json'])
            ->assertCreated()
            ->assertJsonCount(2, 'data.images')
            ->json('data');

        $this->assertStringStartsWith(url('storage/reviews/'), $review['images'][0]);
        $this->assertCount(2, Storage::disk('public')->allFiles('reviews'));

        $this->getJson("/api/v1/products/{$product->id}/reviews")
            ->assertJsonPath('data.0.body', 'Comfortable and smart')
            ->assertJsonCount(2, 'data.0.images');
    }

    public function test_review_shows_the_reviewers_current_profile_photo(): void
    {
        Storage::fake('public');
        $product = $this->orderedProduct();

        // No photo yet: no avatar (the app shows the initial).
        $this->postJson("/api/v1/products/{$product->id}/reviews", ['rating' => 5, 'body' => 'Lovely'])
            ->assertCreated()
            ->assertJsonPath('data.avatar', null);

        // A photo uploaded later shows on the existing review.
        $avatar = $this->post('/api/v1/me/avatar', ['avatar' => UploadedFile::fake()->image('me.jpg')], ['Accept' => 'application/json'])
            ->assertOk()
            ->json('data.avatar_url');

        $this->getJson("/api/v1/products/{$product->id}/reviews")->assertJsonPath('data.0.avatar', $avatar);
        $this->getJson("/api/v1/products/{$product->id}")->assertJsonPath('data.review_summary.latest.0.avatar', $avatar);
    }

    public function test_photos_are_not_kept_when_the_review_is_refused(): void
    {
        Storage::fake('public');
        $product = $this->orderedProduct();
        $review = fn () => $this->post("/api/v1/products/{$product->id}/reviews", [
            'rating' => 5,
            'body' => 'Second try',
            'images' => [UploadedFile::fake()->image('a.jpg')],
        ], ['Accept' => 'application/json']);

        $review()->assertCreated();
        $review()->assertUnprocessable(); // already reviewed

        $this->assertCount(1, Storage::disk('public')->allFiles('reviews'));
    }

    public function test_non_photo_files_are_rejected(): void
    {
        Storage::fake('public');
        $product = $this->orderedProduct();

        $this->post("/api/v1/products/{$product->id}/reviews", [
            'rating' => 5,
            'body' => 'Nice',
            'images' => [UploadedFile::fake()->create('virus.pdf', 10, 'application/pdf')],
        ], ['Accept' => 'application/json'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['images.0']);
    }

    /**
     * A product the signed-in user has ordered (so they may review it).
     */
    private function orderedProduct(): Product
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $product = Product::factory()->create(['price' => '25.00', 'original_price' => '25.00']);
        $variant = ProductVariant::factory()->for($product)->create(['stock_quantity' => 10]);
        $address = Address::factory()->for($user)->create();
        $payment = PaymentMethod::factory()->for($user)->create();

        $this->postJson('/api/v1/cart/items', ['product_variant_id' => $variant->id, 'quantity' => 1]);
        $this->postJson('/api/v1/orders', ['address_id' => $address->id, 'payment_method_id' => $payment->id])->assertCreated();

        return $product;
    }
}
