<?php

use App\Application\Journal\ChangeJournal;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

/*
 * A1 gate on real PostgreSQL: N writer processes commit concurrently for one user while a puller
 * walks the journal with small pages. Because seq is allocated under the user-row lock, commit
 * order equals seq order, so `seq > cursor` never skips a row: the union of everything pulled is
 * exactly 1..change_seq with no gaps and no duplicates.
 *
 * Not wrapped in RefreshDatabase: the writers are separate processes and must see committed
 * rows. The schema is rebuilt before and after.
 */

const WRITERS = 6;
const LOGS_PER_WRITER = 20;
const SHARED_MUTATIONS = 5;
const NOW = '2026-05-28T17:22:00Z';

beforeEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));
afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

/** @return array{0: resource, 1: array<int, resource>} */
function startWriter(string $userId, int $index, array $mutations): array
{
    $file = tempnam(sys_get_temp_dir(), 'habit-writer-');
    file_put_contents($file, json_encode($mutations, JSON_THROW_ON_ERROR));
    $env = array_merge(getenv(), [
        'APP_ENV' => 'testing',
        'DB_CONNECTION' => 'pgsql',
        'DB_HOST' => (string) config('database.connections.pgsql.host'),
        'DB_PORT' => (string) config('database.connections.pgsql.port'),
        'DB_DATABASE' => (string) config('database.connections.pgsql.database'),
        'DB_USERNAME' => (string) config('database.connections.pgsql.username'),
        'DB_PASSWORD' => (string) config('database.connections.pgsql.password'),
    ]);
    $process = proc_open(
        [PHP_BINARY, base_path('tests/Concurrency/writer.php'), $userId, sprintf('01970000-0000-7000-8000-%012d', $index), $file, NOW],
        [1 => ['pipe', 'w'], 2 => ['pipe', 'w']],
        $pipes,
        base_path(),
        $env,
    );
    if (! is_resource($process)) {
        throw new RuntimeException('Could not start writer');
    }
    stream_set_blocking($pipes[1], false);
    stream_set_blocking($pipes[2], false);

    return [$process, $pipes];
}

it('delivers every change exactly once under concurrent writers (A1)', function () {
    $this->freezeClock(NOW);
    // The puller polls as fast as it can; the per-user sync limit is not under test here.
    config(['api.rate_limits.sync_per_minute' => 1_000_000]);
    $user = $this->registerUser();
    $start = ['start_local_date' => '2026-04-29', 'date_mode' => 'backdate'];

    // One habit per writer plus one habit all duplicate mutations target.
    $habits = array_map(fn () => (string) Str::uuid7(), range(0, WRITERS));
    $this->sync($user['token'], array_map(fn ($h) => M::habitCreate($h, overrides: $start), $habits))
        ->assertOk();

    $shared = array_map(fn (int $i) => M::setValue($habits[WRITERS], 1, 0, sprintf('2026-05-%02dT18:00:00Z', $i + 1)), range(0, SHARED_MUTATIONS - 1));
    $writers = [];
    for ($w = 0; $w < WRITERS; $w++) {
        $own = array_map(fn (int $d) => M::setValue($habits[$w], 1, 0, sprintf('2026-05-%02dT18:00:00Z', $d)), range(1, LOGS_PER_WRITER));
        // Writers 0 and 1 also both send the same shared mutations (same mutation ids).
        $mutations = $w < 2 ? [...array_slice($own, 0, 10), ...$shared, ...array_slice($own, 10)] : $own;
        $writers[$w] = startWriter($user['id'], $w, $mutations);
    }

    // Pull with small pages while the writers commit.
    $seen = [];
    $cursor = null;
    $outputs = array_fill(0, WRITERS, '');
    $exitCodes = [];
    $running = WRITERS;
    $polls = 0;
    // Writers must never outlive the test: a failure would otherwise leave them committing
    // into the next test's database (and deadlock the schema reset).
    $this->beforeApplicationDestroyed(function () use ($writers) {
        foreach ($writers as [$process]) {
            if (is_resource($process) && proc_get_status($process)['running']) {
                proc_terminate($process);
            }
        }
    });
    while ($running > 0 && $polls++ < 5000) {
        usleep(5000);
        $page = $this->sync($user['token'], cursor: $cursor, pullLimit: 7)->assertOk();
        array_push($seen, ...array_column($page->json('data.changes'), 'seq'));
        $cursor = $page->json('data.next_cursor');

        $running = 0;
        foreach ($writers as $w => [$process, $pipes]) {
            $outputs[$w] .= (string) stream_get_contents($pipes[1]);
            $status = proc_get_status($process);
            if ($status['running']) {
                $running++;
            } elseif (! isset($exitCodes[$w])) {
                // The exit code is only reported once, by the first non-running status.
                $exitCodes[$w] = $status['exitcode'];
            }
        }
    }
    foreach ($writers as $w => [$process, $pipes]) {
        stream_set_blocking($pipes[1], true);
        $outputs[$w] .= (string) stream_get_contents($pipes[1]);
        $errors = (string) stream_get_contents($pipes[2]);
        proc_close($process);
        expect($exitCodes[$w] ?? null)->toBe(0, "writer {$w} failed: {$errors}");
    }

    // Drain whatever committed after the last poll.
    do {
        $page = $this->sync($user['token'], cursor: $cursor, pullLimit: 7)->assertOk();
        array_push($seen, ...array_column($page->json('data.changes'), 'seq'));
        $cursor = $page->json('data.next_cursor');
    } while ($page->json('data.has_more'));

    $head = (int) DB::table('users')->where('id', $user['id'])->value('change_seq');
    $expectedLogs = WRITERS * LOGS_PER_WRITER + SHARED_MUTATIONS;

    // No gaps, no duplicates, nothing missed.
    expect($seen)->toBe(range(1, $head))
        ->and(DB::table('server_changes')->where('user_id', $user['id'])->count())->toBe($head)
        ->and(DB::table('habit_logs')->count())->toBe($expectedLogs)
        ->and(DB::table('mutation_receipts')->where('user_id', $user['id'])->count())->toBe($expectedLogs + count($habits))
        // 1 user row + habits + one journal row per applied log; the rest are A32 derived
        // entities (habit_progress, period_evaluation) journaled with those logs.
        ->and(DB::table('server_changes')->where('user_id', $user['id'])
            ->whereNotIn('entity_type', ['habit_progress', 'period_evaluation'])->count())
        ->toBe(1 + count($habits) + $expectedLogs);

    // Every mutation was accepted; each shared mutation applied once and was a duplicate once.
    $acks = array_merge(...array_map(fn (string $json) => json_decode($json, true, flags: JSON_THROW_ON_ERROR), $outputs));
    expect(array_unique(array_column($acks, 'status')))->toBe(['accepted']);
    $sharedIds = array_column($shared, 'mutation_id');
    $sharedAcks = array_values(array_filter($acks, fn ($a) => in_array($a['mutation_id'], $sharedIds, true)));
    expect($sharedAcks)->toHaveCount(2 * SHARED_MUTATIONS)
        ->and(count(array_filter($sharedAcks, fn ($a) => $a['duplicate'])))->toBe(SHARED_MUTATIONS);
    foreach ($sharedIds as $id) {
        $pair = array_values(array_filter($sharedAcks, fn ($a) => $a['mutation_id'] === $id));
        expect([$pair[0]['entity_id'], $pair[0]['version']])->toBe([$pair[1]['entity_id'], $pair[1]['version']]);
    }
})->group('concurrency');

it('serialises seq allocation on the user row: a second writer waits for the first to commit (A1)', function () {
    $this->freezeClock(NOW);
    $user = $this->registerUser();
    config(['database.connections.pgsql_second' => config('database.connections.pgsql')]);
    $second = DB::connection('pgsql_second');
    $journal = app(ChangeJournal::class);

    DB::beginTransaction();
    $journal->lockUser($user['id']);
    $first = $journal->append($user['id'], 'habit', (string) Str::uuid7(), 'upsert', 1, []);

    // While the first transaction is open, another connection cannot take a seq.
    $second->statement("SET lock_timeout = '300ms'");
    $blocked = false;
    try {
        $second->select('UPDATE users SET change_seq = change_seq + 1 WHERE id = ? RETURNING change_seq', [$user['id']]);
    } catch (QueryException $e) {
        $blocked = $e->getCode() === '55P03'; // lock_not_available
    }
    expect($blocked)->toBeTrue('a concurrent writer allocated a seq while the first transaction was open');

    DB::commit();
    $next = (int) $second->selectOne('UPDATE users SET change_seq = change_seq + 1 WHERE id = ? RETURNING change_seq', [$user['id']])->change_seq;
    expect($next)->toBe($first + 1);
    $second->disconnect();
})->group('concurrency');
