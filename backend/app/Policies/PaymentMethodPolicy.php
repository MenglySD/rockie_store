<?php

namespace App\Policies;

use App\Models\PaymentMethod;
use App\Models\User;

class PaymentMethodPolicy
{
    public function view(User $user, PaymentMethod $paymentMethod): bool
    {
        return $paymentMethod->user_id === $user->id;
    }

    public function update(User $user, PaymentMethod $paymentMethod): bool
    {
        return $paymentMethod->user_id === $user->id;
    }

    public function delete(User $user, PaymentMethod $paymentMethod): bool
    {
        return $paymentMethod->user_id === $user->id;
    }
}
