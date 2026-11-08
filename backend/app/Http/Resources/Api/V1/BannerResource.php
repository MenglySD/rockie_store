<?php

namespace App\Http\Resources\Api\V1;

use App\Models\Banner;
use App\Support\MediaUrl;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Banner */
class BannerResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'image_url' => MediaUrl::resolve($this->image_url),
            'product_id' => $this->product_id,
            'sort_order' => $this->sort_order,
        ];
    }
}
