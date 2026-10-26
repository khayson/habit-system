<?php

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\DatabaseTruncation;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\RateLimiter;

// Not RefreshDatabase: on PostgreSQL a lock's duplicate-key insert would abort the test's own
// transaction. Production takes these locks outside any transaction (the tick, the scheduler,
// ClosePeriodsJob's unique lock at dispatch from the console command).
uses(DatabaseTruncation::class);

/*
 * A54: production keeps the cache on Neon (CACHE_STORE=database). The pieces that depend on it
 * work there: atomic locks (the tick, withoutOverlapping) and the rate limiters.
 */

beforeEach(fn () => config(['cache.default' => 'database']));

it('holds an atomic lock: a second holder is refused until it is released', function () {
    $first = Cache::lock('internal-tick', 120);
    expect($first->get())->toBeTrue()
        ->and(Cache::lock('internal-tick', 120)->get())->toBeFalse();
    $first->release();
    expect(Cache::lock('internal-tick', 120)->get())->toBeTrue();
});

it('keeps scheduled commands from overlapping', function () {
    $event = app(Schedule::class)->command('habits:close-periods')->withoutOverlapping(10);
    expect($event->mutex->create($event))->toBeTrue()
        ->and($event->mutex->exists($event))->toBeTrue()
        ->and($event->mutex->create($event))->toBeFalse();
    $event->mutex->forget($event);
    expect($event->mutex->exists($event))->toBeFalse();
});

it('counts rate-limit hits across requests', function () {
    RateLimiter::clear('ip:203.0.113.9');
    RateLimiter::hit('ip:203.0.113.9', 60);
    RateLimiter::hit('ip:203.0.113.9', 60);
    expect(RateLimiter::attempts('ip:203.0.113.9'))->toBe(2)
        ->and(RateLimiter::tooManyAttempts('ip:203.0.113.9', 2))->toBeTrue();
});
