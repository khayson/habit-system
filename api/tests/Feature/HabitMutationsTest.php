<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Phase 4.1 (A34, A35): contract-fixtures/habit/habit_mutations.json and log_increment.json,
 * replayed step by step through /sync on real PostgreSQL.
 */

/** @return array<string, mixed> */
function habitFixture(string $name): array
{
    return contractFixture("habit/{$name}.json");
}

/**
 * Creates the case's habit on 2026-05-01 and returns its id.
 *
 * @param  array<string, mixed>  $habit
 */
function createCaseHabit(object $test, string $token, array $habit): string
{
    $id = (string) Str::uuid7();
    $ack = $test->sync($token, [M::habitCreate($id, $habit['type'], $habit['target_value'], [
        'unit' => $habit['unit'] ?? null,
        'category' => $habit['category'] ?? 'health',
        'frequency_type' => $habit['frequency_type'] ?? 'daily',
        'frequency_config' => $habit['frequency_config'] ?? [],
        'start_local_date' => '2026-05-01',
        'date_mode' => 'backdate',
    ])])->json('data.acks.0');
    expect($ack['status'])->toBe('accepted', json_encode($ack));

    return $id;
}

/** The canonical habit as the journal last published it. */
function canonicalHabit(string $userId, string $habitId): array
{
    $row = DB::table('server_changes')->where('user_id', $userId)->where('entity_type', 'habit')->where('entity_id', $habitId)->orderByDesc('seq')->first();

    return json_decode((string) $row->payload, true);
}

function journalCount(string $userId): int
{
    return DB::table('server_changes')->where('user_id', $userId)->count();
}

/** @param array<string, mixed> $expect */
function expectAck(array $ack, array $expect): void
{
    expect($ack['status'])->toBe($expect['status'], json_encode($ack));
    foreach (['version', 'duplicate', 'resolved_date'] as $key) {
        if (array_key_exists($key, $expect)) {
            expect($ack[$key] ?? null)->toBe($expect[$key], "{$key}: ".json_encode($ack));
        }
    }
    if (isset($expect['error_code'])) {
        expect($ack['error']['code'])->toBe($expect['error_code']);
    }
    if (isset($expect['current_version'])) {
        expect($ack['error']['current_version'])->toBe($expect['current_version']);
    }
}

it('replays every habit_mutations.json case', function (array $case) {
    $fixture = habitFixture('habit_mutations');
    $this->freezeClock($fixture['now']);
    $maya = $this->registerUser('Maya');
    $habitId = createCaseHabit($this, $maya['token'], $case['habit']);
    $created = canonicalHabit($maya['id'], $habitId);
    $editable = fn (array $h) => [
        'name' => $h['name'], 'category' => $h['category'], 'target_value' => $h['target_value'],
        'unit' => $h['unit'], 'frequency_type' => $h['frequency_type'], 'frequency_config' => (object) $h['frequency_config'],
    ];

    foreach ($case['steps'] as $i => $step) {
        $now = $step['now'] ?? $fixture['now'];
        $this->freezeClock($now);
        $current = canonicalHabit($maya['id'], $habitId);
        $isLog = str_starts_with($step['operation'], 'log.');
        $payload = match (true) {
            $isLog => ['habit_id' => $habitId, ...$step['payload']],
            $step['operation'] === 'habit.update' => [...$editable($current), ...$step['payload']],
            default => $step['payload'],
        };
        $before = journalCount($maya['id']);

        $ack = $this->sync($maya['token'], [[
            'mutation_id' => (string) Str::uuid7(),
            'entity' => $isLog ? 'habit_log' : 'habit',
            'entity_id' => $isLog ? (string) Str::uuid7() : $habitId,
            'operation' => $step['operation'],
            'base_version' => $step['base_version'] ?? $current['version'],
            'occurred_at' => $now,
            'captured_timezone' => 'America/Los_Angeles',
            'payload' => $payload,
        ]])->json('data.acks.0');

        expectAck($ack, $step['expect']);
        $journaled = journalCount($maya['id']) > $before;
        if ($step['expect']['status'] !== 'accepted' || ($step['expect']['journaled'] ?? true) === false) {
            expect($journaled)->toBeFalse("step {$i} journals nothing");
        }
        if (isset($step['expect']['current_name'])) {
            expect($ack['error']['current']['name'])->toBe($step['expect']['current_name']);
        }
        if (isset($step['habit'])) {
            $habit = canonicalHabit($maya['id'], $habitId);
            foreach (['name', 'target_value', 'category', 'frequency_type'] as $key) {
                if (array_key_exists($key, $step['habit'])) {
                    expect($habit[$key])->toBe($step['habit'][$key], "step {$i} {$key}");
                }
            }
            if (isset($step['habit']['archived'])) {
                expect($habit['archived_at'] !== null)->toBe($step['habit']['archived'], "step {$i} archived");
            }
            if (isset($step['habit']['active_ranges'])) {
                expect(array_map(fn ($r) => [$r['starts_on'], $r['ends_before']], $habit['active_ranges']))
                    ->toBe($step['habit']['active_ranges'], "step {$i} ranges");
            }
            if (isset($step['habit']['definitions'])) {
                expect($habit['definitions'])->toHaveCount(count($step['habit']['definitions']), "step {$i} definitions");
                foreach ($step['habit']['definitions'] as $j => $definition) {
                    foreach ($definition as $key => $value) {
                        expect($habit['definitions'][$j][$key])->toBe($value, "step {$i} definition {$j} {$key}");
                    }
                }
                expect($habit['definition_version'])->toBe(end($habit['definitions'])['version'], 'the habit projects the latest definition');
            }
        }
    }
    expect($created['version'])->toBe(1);
})->with(function () {
    foreach (habitFixture('habit_mutations')['cases'] as $case) {
        yield $case['name'] => [$case];
    }
});

it('replays every log_increment.json case', function (array $case) {
    $fixture = habitFixture('log_increment');
    $this->freezeClock($fixture['now']);
    $maya = $this->registerUser('Maya');
    $habitId = createCaseHabit($this, $maya['token'], $case['habit']);
    $sent = [];
    $logId = (string) Str::uuid7();

    foreach ($case['steps'] as $i => $step) {
        $operation = $step['operation'] ?? 'log.increment';
        if (isset($step['replay_of'])) {
            $mutation = $sent[$step['replay_of']];
        } elseif ($operation === 'habit.archive') {
            $mutation = [
                'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit', 'entity_id' => $habitId,
                'operation' => 'habit.archive', 'base_version' => $step['base_version'], 'occurred_at' => $fixture['now'], 'payload' => [],
            ];
        } elseif ($operation === 'log.delete') {
            $mutation = M::delete($logId, $step['base_version'], $habitId);
        } else {
            $mutation = [
                'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit_log', 'entity_id' => $logId,
                'operation' => $operation, 'base_version' => null, 'occurred_at' => $fixture['now'],
                'captured_timezone' => 'America/Los_Angeles',
                'payload' => array_filter([
                    'habit_id' => $habitId, 'delta' => $step['delta'],
                    'date_mode' => $step['date_mode'] ?? null, 'log_date' => $step['log_date'] ?? null,
                ], fn ($v) => $v !== null),
            ];
        }
        $sent[$i] = $mutation;
        $before = journalCount($maya['id']);

        $ack = $this->sync($maya['token'], [$mutation])->json('data.acks.0');

        expectAck($ack, $step['expect']);
        if ($step['expect']['status'] !== 'accepted' || ($step['expect']['duplicate'] ?? false)) {
            expect(journalCount($maya['id']))->toBe($before, "step {$i} journals nothing");
        }
        if (isset($step['expect']['value'])) {
            $log = DB::table('habit_logs')->where('id', $ack['entity_id'])->first();
            $change = collect($this->sync($maya['token'])->json('data.changes'))->last(fn ($c) => $c['entity'] === 'habit_log');
            expect($change['payload']['value'])->toBe($step['expect']['value'], "step {$i} value")
                ->and((int) $log->version)->toBe($step['expect']['version']);
        }
        if ($step['expect']['error_code'] ?? null) {
            expect(json_encode($ack))->not->toContain('SQLSTATE');
        }
        if (($step['expect']['error_code'] ?? null) === 'resource_deleted') {
            expect($ack['error']['current']['deleted_at'])->not->toBeNull('the tombstone is current');
        }
    }
})->with(function () {
    foreach (habitFixture('log_increment')['cases'] as $case) {
        yield $case['name'] => [$case];
    }
});
