<?php

use App\Application\Accounts\AccountPurger;
use App\Application\Mutations\MutationApplier;
use App\Exceptions\AccountDeleted;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Tests\Support\M;

/*
 * A49 on real PostgreSQL: a write racing the deletion either commits before it (and is purged) or
 * gets AccountDeleted (401) and writes nothing; never a row left behind. Separate processes, so
 * not wrapped in RefreshDatabase; the schema is rebuilt before and after.
 */

const RACE_NOW = '2026-05-28T17:22:00Z';

beforeEach(function () {
    Artisan::call('migrate:fresh', ['--force' => true]);
    $this->freezeClock(RACE_NOW);
    $this->user = $this->registerUser('Maya Chen', 'race@example.com');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->user['token'], [M::habitCreate($this->habit, overrides: ['start_local_date' => '2026-05-01', 'date_mode' => 'backdate'])])->assertOk();
});
afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

/** @return array{0: resource, 1: array<int, resource>} */
function raceChild(array $args): array
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

/** @return array{string, string} */
function raceFinish(array $child): array
{
    [$process, $pipes] = $child;
    $out = stream_get_contents($pipes[1]);
    $err = stream_get_contents($pipes[2]);
    proc_close($process);

    return [(string) $out, (string) $err];
}

function rowsLeftFor(string $userId, string $habitId): int
{
    $tables = collect(DB::select("select table_name from information_schema.columns where table_schema = 'public' and column_name = 'user_id' and table_name <> 'account_deletions'"))->pluck('table_name');
    $left = $tables->sum(fn (string $t) => DB::table($t)->where('user_id', $userId)->count());
    foreach (['habit_definition_versions', 'habit_active_ranges', 'habit_streak_cache'] as $t) {
        $left += DB::table($t)->where('habit_id', $habitId)->count();
    }

    return $left + DB::table('personal_access_tokens')->where('tokenable_id', $userId)->count()
        + DB::table('users')->where('id', $userId)->count();
}

it('a write that waits on the deletion gets AccountDeleted and writes nothing', function () {
    $deleter = raceChild([base_path('tests/Concurrency/deleter.php'), $this->user['id'], '1500', RACE_NOW]);
    expect(trim((string) fgets($deleter[1][1])))->toBe('locked');

    $mutation = M::setValue($this->habit, 1, 0, '2026-05-28T17:00:00Z');
    expect(fn () => app(MutationApplier::class)->apply($this->user['id'], null, $mutation))->toThrow(AccountDeleted::class);
    [, $err] = raceFinish($deleter);
    expect($err)->toBe('')
        ->and(DB::table('mutation_receipts')->where('mutation_id', $mutation['mutation_id'])->exists())->toBeFalse()
        ->and(DB::table('habit_logs')->where('habit_id', $this->habit)->exists())->toBeFalse();

    app(AccountPurger::class)->purge((string) DB::table('account_deletions')->value('id'));
    expect(rowsLeftFor($this->user['id'], $this->habit))->toBe(0);
});

it('a write that commits first is purged with the rest', function () {
    // The holder takes the user lock and inserts a log, as a mutation would, then commits.
    $holder = raceChild([base_path('tests/Concurrency/lock_holder.php'), $this->user['id'], $this->habit, '2026-05-20', '1500']);
    expect(trim((string) fgets($holder[1][1])))->toBe('locked');

    Queue::fake();
    $password = 'correct horse battery staple';
    app('auth')->forgetGuards();
    $this->withToken($this->user['token'])->deleteJson('/api/v1/me', ['password' => $password])->assertStatus(202);
    [, $err] = raceFinish($holder);
    expect($err)->toBe('')
        ->and(DB::table('habit_logs')->where('habit_id', $this->habit)->count())->toBe(1);

    app(AccountPurger::class)->purge((string) DB::table('account_deletions')->value('id'));
    expect(rowsLeftFor($this->user['id'], $this->habit))->toBe(0);
});
