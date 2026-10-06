<?php

namespace App\Providers;

use App\Domain\Clock;
use App\Http\RequestContext;
use App\Infrastructure\SystemClock;
use Carbon\CarbonImmutable;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(Clock::class, SystemClock::class);
        $this->app->scoped(RequestContext::class);
    }

    public function boot(): void
    {
        Date::use(CarbonImmutable::class);
        Model::shouldBeStrict(! $this->app->isProduction());

        $this->configureRateLimiting();
    }

    /**
     * ASSUMPTION(A0-limits): the spec asks for per-user/device/IP limits but gives a number only for
     * avatar uploads (A20: 10/hour). The other values are conservative defaults to tune in Phase 7.
     */
    private function configureRateLimiting(): void
    {
        $byUserOrIp = fn (Request $request): string => $request->user()
            ? 'user:'.$request->user()->getAuthIdentifier()
            : 'ip:'.$request->ip();
        $email = fn (Request $request): string => mb_strtolower(trim($request->string('email')->toString()));

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)->by($byUserOrIp($request)));

        // Login / register: per IP, and per normalized email + IP to slow credential stuffing.
        RateLimiter::for('auth', fn (Request $request) => [
            Limit::perMinute(20)->by('ip:'.$request->ip()),
            Limit::perMinute(5)->by('email:'.$email($request).'|'.$request->ip()),
        ]);

        RateLimiter::for('password-reset', fn (Request $request) => [
            Limit::perHour(20)->by('ip:'.$request->ip()),
            Limit::perHour(5)->by('email:'.$email($request)),
        ]);

        RateLimiter::for('sync', fn (Request $request) => Limit::perMinute(60)->by($byUserOrIp($request)));

        RateLimiter::for('avatar-upload', fn (Request $request) => Limit::perHour(10)->by($byUserOrIp($request)));
    }
}
