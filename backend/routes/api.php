<?php

use App\Http\Controllers\Api\V1\AddressController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BannerController;
use App\Http\Controllers\Api\V1\CartController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\CouponController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\PasswordResetController;
use App\Http\Controllers\Api\V1\PaymentMethodController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\ProductReviewController;
use App\Http\Controllers\Api\V1\ProfileController;
use App\Http\Controllers\Api\V1\SupportMessageController;
use Illuminate\Support\Facades\Route;

/*
| All routes are prefixed with /api (by Laravel) and /v1 (below).
| Rate limiters are defined in AppServiceProvider.
*/

Route::prefix('v1')->group(function () {
    // Authentication
    Route::prefix('auth')->group(function () {
        Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:register');
        Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
        Route::post('/firebase', [AuthController::class, 'firebase'])->middleware('throttle:register');

        Route::post('/forgot-password', [PasswordResetController::class, 'forgot'])->middleware('throttle:otp-request');
        Route::post('/verify-otp', [PasswordResetController::class, 'verify'])->middleware('throttle:otp-verify');
        Route::post('/reset-password', [PasswordResetController::class, 'reset'])->middleware('throttle:otp-verify');

        Route::post('/logout', [AuthController::class, 'logout'])->middleware('auth:sanctum');
    });

    // Public catalog
    Route::get('/banners', [BannerController::class, 'index']);
    Route::get('/categories', [CategoryController::class, 'index']);
    Route::get('/products', [ProductController::class, 'index']);
    Route::get('/products/{product}', [ProductController::class, 'show']);
    Route::get('/products/{product}/reviews', [ProductReviewController::class, 'index']);

    // Guests or signed-in users (Bearer token optional)
    Route::post('/support/messages', [SupportMessageController::class, 'store'])->middleware('throttle:support');

    Route::middleware('auth:sanctum')->group(function () {
        // Profile
        Route::get('/me', [ProfileController::class, 'show']);
        Route::patch('/me', [ProfileController::class, 'update']);
        Route::post('/me/avatar', [ProfileController::class, 'updateAvatar']);
        Route::delete('/me/avatar', [ProfileController::class, 'destroyAvatar']);
        Route::post('/me/change-password', [ProfileController::class, 'changePassword']);

        // Addresses and payment methods
        Route::apiResource('addresses', AddressController::class);
        Route::apiResource('payment-methods', PaymentMethodController::class)
            ->parameters(['payment-methods' => 'paymentMethod']);

        // Cart
        Route::get('/cart', [CartController::class, 'show']);
        Route::post('/cart/items', [CartController::class, 'storeItem']);
        Route::patch('/cart/items/{item}', [CartController::class, 'updateItem']);
        Route::patch('/cart/selection', [CartController::class, 'updateSelection']);
        Route::delete('/cart/items/{item}', [CartController::class, 'destroyItem']);
        Route::post('/cart/coupon', [CartController::class, 'applyCoupon']);
        Route::delete('/cart/coupon', [CartController::class, 'removeCoupon']);

        // Coupons
        Route::get('/coupons', [CouponController::class, 'index']);

        // Orders
        Route::get('/orders', [OrderController::class, 'index']);
        Route::post('/orders', [OrderController::class, 'store']);
        Route::get('/orders/{order}', [OrderController::class, 'show']);

        // Reviews (after purchase)
        Route::post('/products/{product}/reviews', [ProductReviewController::class, 'store']);

        // Notifications
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
        Route::post('/notifications/{notification}/read', [NotificationController::class, 'markRead']);
    });
});
