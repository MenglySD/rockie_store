<?php

namespace App\Support;

use Illuminate\Support\Str;

/**
 * Resolves a stored media value to an absolute URL.
 *
 * Seeded images are stored as paths relative to public/ (for example
 * "storage/seed-images/product/pants.png") and resolved with asset() at
 * response time, so the URL host follows the request: a phone calling
 * http://192.168.1.10:8000 gets image URLs on that same host.
 */
final class MediaUrl
{
    public static function resolve(?string $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (Str::startsWith($value, ['http://', 'https://'])) {
            return $value;
        }

        return asset($value);
    }
}
