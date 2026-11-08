<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;
use Kreait\Firebase\Contract\Auth as FirebaseAuth;
use Kreait\Firebase\Factory as FirebaseFactory;
use RuntimeException;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(FirebaseAuth::class, function () {
            $credentials = config('services.firebase.credentials');

            if (! $credentials) {
                throw new RuntimeException('Firebase is not configured. Set FIREBASE_CREDENTIALS in .env.');
            }

            // Absolute path, or relative to the project root.
            $path = is_file($credentials) ? $credentials : base_path($credentials);

            $factory = (new FirebaseFactory)->withServiceAccount($path);

            if ($projectId = config('services.firebase.project_id')) {
                $factory = $factory->withProjectId($projectId);
            }

            return $factory->createAuth();
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->configureRateLimiting();
    }

    private function configureRateLimiting(): void
    {
        $email = fn (Request $request) => Str::lower((string) $request->input('email'));

        RateLimiter::for('login', fn (Request $request) => Limit::perMinute(5)
            ->by('login:'.$email($request).'|'.$request->ip())
            ->response(fn (Request $request, array $headers) => response()->json([
                'message' => 'Too many login attempts. Please try again in a minute.',
            ], 429, $headers)));

        RateLimiter::for('register', fn (Request $request) => Limit::perMinute(10)->by('register:'.$request->ip()));

        // 1 code per minute and 5 per hour per email, plus a per-IP cap.
        RateLimiter::for('otp-request', fn (Request $request) => [
            Limit::perMinute(1)->by('otp-minute:'.$email($request))->response(fn (Request $request, array $headers) => response()->json([
                'message' => 'Please wait a minute before requesting another code.',
            ], 429, $headers)),
            Limit::perHour(5)->by('otp-hour:'.$email($request))->response(fn (Request $request, array $headers) => response()->json([
                'message' => 'Too many codes requested. Please try again later.',
            ], 429, $headers)),
            Limit::perHour(30)->by('otp-ip:'.$request->ip()),
        ]);

        RateLimiter::for('otp-verify', fn (Request $request) => Limit::perMinute(10)->by('otp-verify:'.$email($request).'|'.$request->ip()));

        RateLimiter::for('support', fn (Request $request) => Limit::perMinute(5)->by('support:'.$request->ip()));
    }
}
