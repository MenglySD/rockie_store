<?php

namespace App\Http\Resources\Api\V1;

use App\Models\User;
use App\Support\MediaUrl;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin User */
class UserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'gender' => $this->gender?->value,
            'phone' => $this->phone,
            'avatar_url' => MediaUrl::resolve($this->avatar_url),
            'has_password' => $this->hasPassword(),
            'is_social_account' => $this->firebase_uid !== null,
            'email_verified_at' => $this->email_verified_at?->toIso8601ZuluString(),
            'created_at' => $this->created_at?->toIso8601ZuluString(),
        ];
    }
}
