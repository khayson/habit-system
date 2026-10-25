<?php

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

/*
 * A51 on real PostgreSQL: a log write racing habit.delete either commits first (and is removed
 * with the habit) or is rejected; never a log left under a deleted habit. Separate processes, so
 * not wrapped in RefreshDatabase; the schema is rebuilt before and after.
 */

beforeEach(function () {
    Artisan::call('migrate:fresh', ['--force' => true]);
    $this->freezeClock('2026-05-30T17:00:00Z');
    $this->user = $this->registerUser('Maya Chen', 'habit-race@example.com');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->user['token'], [M::habitCreate($this->habit, overrides: ['start_local_date' => '2026-05-01', 'date_mode' => 'backdate'])])->assertOk();
});
afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

/** @return array{0: resource, 1: array<int, resource>} */
function habitRaceChild(array $args): array
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

it('a log that commits before the delete is removed with the habit', function () {
    // The holder takes the user lock and inserts a log, as a log mutation would, then commits.
    $holder = habitRaceChild([base_path('tests/Concurrency/lock_holder.php'), $this->user['id'], $this->habit, '2026-05-20', '1500']);
    expect(trim((string) fgets($holder[1][1])))->toBe('locked');

    $mutation = [...contractFixture('habit/habit_delete.json')['delete']['mutation'],
        'mutation_id' => (string) Str::uuid7(), 'entity_id' => $this->habit, 'base_version' => 1];
    $this->sync($this->user['token'], [$mutation])->assertJsonPath('data.acks.0.status', 'accepted');
    [$process, $pipes] = $holder;
    $err = stream_get_contents($pipes[2]);
    proc_close($process);

    expect($err)->toBe('')
        ->and(DB::table('habit_logs')->where('habit_id', $this->habit)->count())->toBe(0)
        ->and(DB::table('habits')->where('id', $this->habit)->value('deleted_at'))->not->toBeNull();
});

it('a log that arrives after the delete is rejected and writes nothing', function () {
    $mutation = [...contractFixture('habit/habit_delete.json')['delete']['mutation'],
        'mutation_id' => (string) Str::uuid7(), 'entity_id' => $this->habit, 'base_version' => 1];
    $this->sync($this->user['token'], [$mutation])->assertJsonPath('data.acks.0.status', 'accepted');

    $ack = $this->sync($this->user['token'], [M::setValue($this->habit, 1, 0, '2026-05-30T16:00:00Z')])->json('data.acks.0');
    expect([$ack['status'], $ack['error']['code']])->toBe(['conflict', 'resource_deleted'])
        ->and(DB::table('habit_logs')->where('habit_id', $this->habit)->count())->toBe(0);
});
