<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Review;
use App\Support\MediaUrl;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Review */
class ReviewResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'product_id' => $this->product_id,
            'name' => $this->reviewer_name,
            'avatar' => $this->avatar(),
            'rating' => $this->rating,
            'body' => $this->body,
            'images' => $this->images->map(fn ($image) => MediaUrl::resolve($image->url))->values(),
            'is_verified_purchase' => $this->order_id !== null,
            'created_at' => $this->created_at?->toIso8601ZuluString(),
        ];
    }

    /**
     * The reviewer's current profile photo (it may have changed since the
     * review was written), else the avatar saved with the review: an emoji
     * such as "🍌", an image URL or an uploaded photo path. Null when none.
     */
    private function avatar(): ?string
    {
        $current = $this->relationLoaded('user') ? $this->user?->avatar_url : null;
        $avatar = $current ?: $this->reviewer_avatar;

        if ($avatar === null || $avatar === '') {
            return null;
        }

        return Str::startsWith($avatar, ['storage/', 'http://', 'https://'])
            ? MediaUrl::resolve($avatar)
            : $avatar;
    }
}
