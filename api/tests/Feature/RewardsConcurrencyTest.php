<?php

use App\Application\Periods\PeriodCloser;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

require_once __DIR__.'/../Support/writers.php';

/*
 * A39 to A41 on real PostgreSQL, from separate processes (separate connections): concurrent
 * writes credit XP once per habit-day, and concurrent closers grant and spend once. Not wrapped
 * in RefreshDatabase: children must see committed rows. The schema is rebuilt before and after.
 */

const REWARDS_NOW = '2026-05-28T17:22:00Z';

beforeEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));
afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

it('credits one completion when two devices cross the target at the same time', function () {
    $this->freezeClock(REWARDS_NOW);
    $user = $this->registerUser();
    $water = (string) Str::uuid7();
    $this->sync($user['token'], [M::habitCreate($water, 'quantity', '2000.000', ['unit' => 'ml', 'category' => 'health'])])
        ->assertJsonPath('data.acks.0.status', 'accepted');
    $increment = fn () => [
        'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit_log', 'entity_id' => (string) Str::uuid7(),
        'operation' => 'log.increment', 'base_version' => null, 'occurred_at' => REWARDS_NOW,
        'captured_timezone' => 'America/Los_Angeles', 'payload' => ['habit_id' => $water, 'delta' => '1500.000'],
    ];

    $writers = [startWriter($user['id'], 61, [$increment()], REWARDS_NOW), startWriter($user['id'], 62, [$increment()], REWARDS_NOW)];
    $acks = array_merge(...array_map(fn ($w) => json_decode(finishProcess($w), true, flags: JSON_THROW_ON_ERROR), $writers));

    expect(array_unique(array_column($acks, 'status')))->toBe(['accepted'])
        ->and(DB::table('habit_logs')->where('habit_id', $water)->value('value'))->toBe('3000.000')
        ->and(DB::table('xp_ledger')->pluck('delta')->map(fn ($d) => (int) $d)->all())->toBe([10])
        ->and((int) DB::table('users')->where('id', $user['id'])->value('xp'))->toBe(10);
    assertLedgersMatchCaches($user['id']);
})->group('concurrency');

it('grants the month and spends each missed period once when closers race', function () {
    $this->freezeClock('2026-05-20T16:00:00Z');
    $user = $this->registerUser();
    $version = (int) DB::table('users')->where('id', $user['id'])->value('version');
    $this->sync($user['token'], [M::setAutoFreeze($user['id'], true, $version)])->assertJsonPath('data.acks.0.status', 'accepted');
    $habit = (string) Str::uuid7();
    $this->sync($user['token'], [M::habitCreate($habit, overrides: ['start_local_date' => '2026-05-20'])])->assertJsonPath('data.acks.0.status', 'accepted');
    $this->freezeClock('2026-05-22T17:00:00Z');

    $closers = [startCloser($user['id'], 3, '2026-05-22T17:00:00Z'), startCloser($user['id'], 3, '2026-05-22T17:00:00Z')];
    array_map(finishProcess(...), $closers);
    expect(app(PeriodCloser::class)->closeUser($user['id']))->toBe(0, 'nothing left to do');

    expect(DB::table('freeze_ledger')->orderBy('created_at')->orderBy('id')->pluck('source_key')->all())->toBe([
        'signup', 'month:2026-05', "spend:{$habit}:d:2026-05-20", "spend:{$habit}:d:2026-05-21",
    ])->and(DB::table('freeze_usage')->count())->toBe(2)
        ->and((int) DB::table('users')->where('id', $user['id'])->value('freeze_balance'))->toBe(0);
    assertLedgersMatchCaches($user['id']);
})->group('concurrency');
