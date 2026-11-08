<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Models\Order;
use App\Models\Product;
use App\Models\Review;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class ReviewService
{
    /**
     * @param  array{rating: int, body: string, images?: list<UploadedFile>}  $data
     */
    public function create(User $user, Product $product, array $data): Review
    {
        $paths = [];

        try {
            return $this->createReview($user, $product, $data, $paths);
        } catch (\Throwable $e) {
            // Don't leave uploaded photos behind when the review is refused.
            Storage::disk('public')->delete($paths);

            throw $e;
        }
    }

    /**
     * @param  array{rating: int, body: string, images?: list<UploadedFile>}  $data
     * @param  list<string>  $paths  filled with the stored photo paths
     */
    private function createReview(User $user, Product $product, array $data, array &$paths): Review
    {
        $order = Order::where('user_id', $user->id)
            ->where('status', '!=', OrderStatus::Cancelled)
            ->whereHas('items', fn ($q) => $q->where('product_id', $product->id))
            ->latest('placed_at')
            ->first();

        if (! $order) {
            throw new AuthorizationException('You can review a product after you have ordered it.');
        }

        return DB::transaction(function () use ($user, $product, $order, $data, &$paths) {
            $product = Product::whereKey($product->id)->lockForUpdate()->first();

            if ($product->reviews()->where('user_id', $user->id)->exists()) {
                throw ValidationException::withMessages(['rating' => ['You have already reviewed this product.']]);
            }

            $review = $product->reviews()->create([
                'user_id' => $user->id,
                'order_id' => $order->id,
                'reviewer_name' => $user->name,
                'reviewer_avatar' => $user->avatar_url,
                'rating' => $data['rating'],
                'body' => $data['body'],
            ]);

            foreach ($data['images'] ?? [] as $file) {
                $paths[] = $path = $file->store('reviews', 'public');
                $review->images()->create(['url' => 'storage/'.$path]);
            }

            // Same running-average update as Product.addReview() in the Flutter app.
            $count = $product->review_count;
            $product->forceFill([
                'rating_avg' => round((((float) $product->rating_avg * $count) + $data['rating']) / ($count + 1), 2),
                'review_count' => $count + 1,
            ])->save();

            return $review->load(['images', 'user:id,avatar_url']);
        });
    }
}
