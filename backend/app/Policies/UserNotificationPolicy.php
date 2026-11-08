<?php

namespace App\Policies;

use App\Models\User;
use App\Models\UserNotification;

class UserNotificationPolicy
{
    public function update(User $user, UserNotification $notification): bool
    {
        return $notification->user_id === $user->id;
    }
}
