<?php

namespace App\Providers;

use App\Domain\Clock;
use App\Domain\Habit\HabitTypeRegistry;
use App\Http\RequestContext;
use App\Infrastructure\SystemClock;
use App\Models\PersonalAccessToken;
use Carbon\CarbonImmutable;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\Sanctum;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(Clock::class, SystemClock::class);
        $this->app->scoped(RequestContext::class);
        $this->app->singleton(HabitTypeRegistry::class, fn () => HabitTypeRegistry::withBuiltins());
    }

    public function boot(): void
    {
        Date::use(CarbonImmutable::class);
        Model::shouldBeStrict(! $this->app->isProduction());
        Sanctum::usePersonalAccessTokenModel(PersonalAccessToken::class);

        $this->configureRateLimiting();
    }

    /**
     * Limits come from config/api.php (env-tunable). Keyed by user id when authenticated, IP
     * otherwise, so users behind one carrier IP get independent buckets.
     */
    private function configureRateLimiting(): void
    {
        $limit = fn (string $key): int => config()->integer("api.rate_limits.{$key}");
        $byUserOrIp = fn (Request $request): string => $request->user()
            ? 'user:'.$request->user()->getAuthIdentifier()
            : 'ip:'.$request->ip();
        $email = fn (Request $request): string => mb_strtolower(trim($request->string('email')->toString()));

        RateLimiter::for('api', fn (Request $request) => Limit::perMinute($limit('api_per_minute'))->by($byUserOrIp($request)));

        // Login / register: per IP, and per normalized email + IP to slow credential stuffing.
        RateLimiter::for('auth', fn (Request $request) => [
            Limit::perMinute($limit('auth_per_minute_per_ip'))->by('ip:'.$request->ip()),
            Limit::perMinute($limit('auth_per_minute_per_email'))->by('email:'.$email($request).'|'.$request->ip()),
        ]);

        // A49: DELETE /me checks a password, so it gets the login limits, per IP and per user.
        RateLimiter::for('account-delete', fn (Request $request) => [
            Limit::perMinute($limit('auth_per_minute_per_ip'))->by('ip:'.$request->ip()),
            Limit::perMinute($limit('auth_per_minute_per_email'))->by($byUserOrIp($request)),
        ]);
        RateLimiter::for('password-reset', fn (Request $request) => [
            Limit::perHour($limit('password_reset_per_hour_per_ip'))->by('ip:'.$request->ip()),
            Limit::perHour($limit('password_reset_per_hour_per_email'))->by('email:'.$email($request)),
        ]);

        RateLimiter::for('sync', fn (Request $request) => Limit::perMinute($limit('sync_per_minute'))->by($byUserOrIp($request)));

        RateLimiter::for('exports', fn (Request $request) => Limit::perHour($limit('exports_per_hour'))->by($byUserOrIp($request)));

        // A54: the outside timer calls every 5 minutes; anything faster is someone else.
        RateLimiter::for('tick', fn (Request $request) => Limit::perMinute($limit('tick_per_minute'))->by('ip:'.$request->ip()));

        // A55: the ops status is read by one operator now and then.
        RateLimiter::for('ops', fn (Request $request) => Limit::perMinute($limit('ops_per_minute'))->by('ip:'.$request->ip()));

        RateLimiter::for('avatar-upload', fn (Request $request) => Limit::perHour($limit('avatar_uploads_per_hour'))->by($byUserOrIp($request)));
    }
}
