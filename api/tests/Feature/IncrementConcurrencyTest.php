<?php

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

require_once __DIR__.'/../Support/writers.php';

/*
 * Phase 4.1 gate (A35, spec acceptance "concurrent increments") on real PostgreSQL: five writer
 * processes each add +250 to the same habit-day at the same time. The total is exact, versions
 * rise strictly with no gap, and each receipt has exactly one journal row.
 *
 * Not wrapped in RefreshDatabase: the writers are separate processes and must see committed
 * rows. The schema is rebuilt before and after.
 */

const INCREMENT_WRITERS = 5;
const INCREMENT_NOW = '2026-05-28T17:22:00Z';

beforeEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));
afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

it('adds concurrent increments exactly: no lost update, strictly rising versions, one journal row each', function () {
    $this->freezeClock(INCREMENT_NOW);
    $user = $this->registerUser();
    $water = (string) Str::uuid7();
    $this->sync($user['token'], [M::habitCreate($water, 'quantity', '2000.000', ['unit' => 'ml', 'category' => 'health'])])
        ->assertJsonPath('data.acks.0.status', 'accepted');

    $mutations = array_map(fn () => [
        'mutation_id' => (string) Str::uuid7(),
        'entity' => 'habit_log',
        'entity_id' => (string) Str::uuid7(),
        'operation' => 'log.increment',
        'base_version' => null,
        'occurred_at' => INCREMENT_NOW,
        'captured_timezone' => 'America/Los_Angeles',
        'payload' => ['habit_id' => $water, 'delta' => '250.000'],
    ], range(1, INCREMENT_WRITERS));

    $writers = [];
    foreach ($mutations as $i => $mutation) {
        $writers[] = startWriter($user['id'], 50 + $i, [$mutation], INCREMENT_NOW);
    }
    $this->beforeApplicationDestroyed(function () use ($writers) {
        foreach ($writers as [$process]) {
            if (is_resource($process) && proc_get_status($process)['running']) {
                proc_terminate($process);
            }
        }
    });
    $acks = [];
    foreach ($writers as $w => [$process, $pipes]) {
        stream_set_blocking($pipes[1], true);
        stream_set_blocking($pipes[2], true);
        $out = (string) stream_get_contents($pipes[1]);
        $errors = (string) stream_get_contents($pipes[2]);
        expect(proc_close($process))->toBe(0, "writer {$w} failed: {$errors}");
        array_push($acks, ...json_decode($out, true, flags: JSON_THROW_ON_ERROR));
    }

    expect(array_unique(array_column($acks, 'status')))->toBe(['accepted']);
    $versions = array_column($acks, 'version');
    sort($versions);
    expect($versions)->toBe(range(1, INCREMENT_WRITERS), 'strictly rising, no gap, none repeated');

    $log = DB::table('habit_logs')->where('habit_id', $water)->sole();
    expect($log->value)->toBe('1250.000')
        ->and((int) $log->version)->toBe(INCREMENT_WRITERS);
    $journal = DB::table('server_changes')->where('user_id', $user['id'])->where('entity_type', 'habit_log')->orderBy('seq')->get();
    expect($journal->pluck('version')->map(fn ($v) => (int) $v)->all())->toBe(range(1, INCREMENT_WRITERS))
        ->and(DB::table('mutation_receipts')->whereIn('mutation_id', array_column($mutations, 'mutation_id'))->count())->toBe(INCREMENT_WRITERS);
})->group('concurrency');
