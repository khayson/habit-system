<?php

use App\Application\Periods\PeriodCloser;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

/*
 * A10 / A1 on real PostgreSQL: the closer and mutations from separate processes (separate
 * connections). Not wrapped in RefreshDatabase: children must see committed rows. The schema is
 * rebuilt before and after.
 */

const CLOSER_NOW = '2026-05-30T17:00:00Z'; // 10:00 on 30 May in Los Angeles

beforeEach(function () {
    Artisan::call('migrate:fresh', ['--force' => true]);
    // A user with a daily habit from 1 May; the clock then stands at CLOSER_NOW.
    $this->seed = function (): array {
        $this->freezeClock('2026-05-28T17:22:00Z');
        $user = $this->registerUser();
        $habit = (string) Str::uuid7();
        $this->sync($user['token'], [M::habitCreate($habit, overrides: ['start_local_date' => '2026-05-01', 'date_mode' => 'backdate'])])->assertOk();
        $this->freezeClock(CLOSER_NOW);

        return [$user, $habit];
    };
});
afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

/** @return array{0: resource, 1: array<int, resource>} */
function startChild(array $args): array
{
    $env = array_merge(getenv(), [
        'APP_ENV' => 'testing',
        'DB_CONNECTION' => 'pgsql',
        'DB_HOST' => (string) config('database.connections.pgsql.host'),
        'DB_PORT' => (string) config('database.connections.pgsql.port'),
        'DB_DATABASE' => (string) config('database.connections.pgsql.database'),
        'DB_USERNAME' => (string) config('database.connections.pgsql.username'),
        'DB_PASSWORD' => (string) config('database.connections.pgsql.password'),
    ]);
    $process = proc_open([PHP_BINARY, ...$args], [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, base_path(), $env);
    if (! is_resource($process)) {
        throw new RuntimeException('Could not start child process');
    }

    return [$process, $pipes];
}

/** @return array{string, string} stdout and stderr once the child exits */
function finishChild(array $child): array
{
    [$process, $pipes] = $child;
    $out = stream_get_contents($pipes[1]);
    $err = stream_get_contents($pipes[2]);
    proc_close($process);

    return [(string) $out, (string) $err];
}

it('waits for the user lock, so a mutation committing meanwhile is never overwritten (A1)', function () {
    [$user, $habit] = ($this->seed)();
    app(PeriodCloser::class)->closeUser($user['id']);
    expect(DB::table('period_evaluations')->where('period_key', 'd:2026-05-20')->value('completed'))->toBeFalse();

    $holder = startChild([base_path('tests/Concurrency/lock_holder.php'), $user['id'], $habit, '2026-05-20', '1500']);
    expect(trim((string) fgets($holder[1][1])))->toBe('locked');

    // The holder has the lock and an uncommitted late log. A closer that takes the user lock
    // first waits for the commit and then sees the log; one that reads first evaluates stale
    // data and writes it after the holder commits.
    app(PeriodCloser::class)->closeUser($user['id']);
    finishChild($holder);

    expect(DB::table('period_evaluations')->where('period_key', 'd:2026-05-20')->value('completed'))->toBeTrue();
});

it('races late offline logs against the closer: no lost update, no duplicate, no seq gap', function () {
    config(['api.rate_limits.sync_per_minute' => 1_000_000]);
    [$user, $habit] = ($this->seed)();
    app(PeriodCloser::class)->closeUser($user['id']);

    $days = range(2, 25);
    $file = tempnam(sys_get_temp_dir(), 'habit-late-');
    file_put_contents($file, json_encode(array_map(fn (int $d) => M::setValue($habit, 1, 0, sprintf('2026-05-%02dT18:00:00Z', $d)), $days), JSON_THROW_ON_ERROR));

    $closer = startChild([base_path('tests/Concurrency/closer.php'), $user['id'], '25', CLOSER_NOW]);
    $writer = startChild([base_path('tests/Concurrency/writer.php'), $user['id'], '01970000-0000-7000-8000-000000000001', $file, CLOSER_NOW]);
    [$writerOut, $writerErr] = finishChild($writer);
    [$closerOut, $closerErr] = finishChild($closer);
    expect($writerErr)->toBe('')->and($closerErr)->toBe('');
    expect(collect(json_decode($writerOut, true))->pluck('status')->unique()->all())->toBe(['accepted']);

    // No lost update: every late log is reflected in its closed period.
    $evaluations = DB::table('period_evaluations')->where('habit_id', $habit)->get()->keyBy('period_key');
    foreach ($days as $d) {
        expect((bool) $evaluations[sprintf('d:2026-05-%02d', $d)]->completed)->toBeTrue("day {$d}");
    }
    // No duplicate evaluation: one row per closed day (1 to 29 May).
    expect($evaluations)->toHaveCount(29)
        ->and(DB::table('period_evaluations')->select('period_key')->groupBy('period_key')->havingRaw('count(*) > 1')->count())->toBe(0);

    // Gap-free journal, and its latest evaluation versions match the stored revisions.
    $head = (int) DB::table('users')->where('id', $user['id'])->value('change_seq');
    expect(DB::table('server_changes')->where('user_id', $user['id'])->orderBy('seq')->pluck('seq')->map(fn ($s) => (int) $s)->all())
        ->toBe(range(1, $head));
    foreach ($evaluations as $row) {
        $journaled = (int) DB::table('server_changes')->where('entity_type', 'period_evaluation')->where('entity_id', $row->id)->max('version');
        expect($journaled)->toBe((int) $row->revision);
    }

    // The final state is stable: one more run finds nothing to change.
    expect(app(PeriodCloser::class)->closeUser($user['id']))->toBe(0);
    $cache = DB::table('habit_streak_cache')->where('habit_id', $habit)->first();
    expect([(int) $cache->current, (int) $cache->longest])->toBe([0, 24]);
});
