<?php

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

/*
 * A54: POST /api/v1/internal/tick runs the scheduler, then the queue until it is empty, for
 * Render's free tier (no cron, no worker). A missing or wrong X-Tick-Secret, or no TICK_SECRET
 * configured, is 404 (never 401, so it is not advertised). One tick at a time.
 */

const TICK_SECRET_FOR_TEST = 'tick-secret-for-tests-only-0123456789abcdef';

beforeEach(function () {
    config(['api.tick_secret' => TICK_SECRET_FOR_TEST, 'queue.default' => 'database']);
    Cache::forget('tick-ran');
    Cache::forget('tick-scheduled');
});

function tick(object $test, ?string $secret)
{
    return $test->postJson('/api/v1/internal/tick', [], $secret === null ? [] : ['X-Tick-Secret' => $secret]);
}

function assertTickNotFound($response): void
{
    $fixture = contractFixture('envelope/error_404_not_found.json');
    $response->assertStatus(404);
    assertMatchesContract($fixture['body'], $response->json());
}

it('is 404 without the secret, with a wrong one, and when no secret is configured', function () {
    assertTickNotFound(tick($this, null));
    assertTickNotFound(tick($this, 'wrong'));
    assertTickNotFound(tick($this, TICK_SECRET_FOR_TEST.'x'));
    config(['api.tick_secret' => '']);
    assertTickNotFound(tick($this, ''));
    assertTickNotFound(tick($this, TICK_SECRET_FOR_TEST));
});

it('runs due scheduled work and every queued job once, then answers 204', function () {
    app(Schedule::class)->call(fn () => Cache::increment('tick-scheduled'))->everyMinute()->name('tick-test');
    dispatch(fn () => Cache::increment('tick-ran'));
    dispatch(fn () => Cache::increment('tick-ran'));
    expect(DB::table('jobs')->count())->toBe(2);

    tick($this, TICK_SECRET_FOR_TEST)->assertNoContent();

    expect(Cache::get('tick-ran'))->toBe(2)
        ->and(Cache::get('tick-scheduled'))->toBe(1)
        ->and(DB::table('jobs')->count())->toBe(0);

    tick($this, TICK_SECRET_FOR_TEST)->assertNoContent();
    expect(Cache::get('tick-ran'))->toBe(2, 'a job never runs twice');
});

it('does nothing while another tick holds the lock, and still answers 204', function () {
    dispatch(fn () => Cache::increment('tick-ran'));
    $lock = Cache::lock('internal-tick', 120);
    expect($lock->get())->toBeTrue();

    tick($this, TICK_SECRET_FOR_TEST)->assertNoContent();
    expect(Cache::get('tick-ran'))->toBeNull()
        ->and(DB::table('jobs')->count())->toBe(1);

    $lock->release();
    tick($this, TICK_SECRET_FOR_TEST)->assertNoContent();
    expect(Cache::get('tick-ran'))->toBe(1);
});

it('is outside the API auth and does not advertise itself to GET', function () {
    $this->getJson('/api/v1/internal/tick', ['X-Tick-Secret' => TICK_SECRET_FOR_TEST])->assertStatus(405);
});
