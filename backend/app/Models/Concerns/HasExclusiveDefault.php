<?php

namespace App\Models\Concerns;

use Illuminate\Support\Facades\DB;

/**
 * For user-owned records where at most one row per user may be the default
 * (addresses, payment methods). The flag only changes when the user asks.
 */
trait HasExclusiveDefault
{
    public function markAsDefault(): void
    {
        DB::transaction(function () {
            static::query()
                ->where('user_id', $this->user_id)
                ->whereKeyNot($this->getKey())
                ->where('is_default', true)
                ->update(['is_default' => false]);

            $this->forceFill(['is_default' => true])->save();
        });
    }
}
