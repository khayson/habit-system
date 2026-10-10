<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Phase 4.1 (A34, A35, invariant 2): every new operation is owner-scoped; a foreign or missing
 * habit is one answer and nothing of the owner's changes. Archived habits stay in the bootstrap
 * (screen 22 lists them).
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->ben = $this->registerUser('Ben');
    $this->water = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($this->water, 'quantity', '2000.000', ['unit' => 'ml', 'category' => 'health'])]);
});

/** @return array<string, mixed> */
function habitOp(string $habitId, string $operation, int $baseVersion, array $payload = []): array
{
    return [
        'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit', 'entity_id' => $habitId,
        'operation' => $operation, 'base_version' => $baseVersion, 'occurred_at' => '2026-05-28T17:22:00Z', 'payload' => $payload,
    ];
}

it('answers another user\'s habit, or a missing one, with not_found for update, archive and restore', function (string $operation) {
    $payload = $operation === 'habit.update'
        ? ['name' => 'Mine now', 'category' => 'health', 'target_value' => '1.000', 'unit' => 'ml', 'frequency_type' => 'daily', 'frequency_config' => []]
        : [];
    $before = DB::table('habits')->where('id', $this->water)->first();

    foreach ([$this->water, (string) Str::uuid7()] as $id) {
        $ack = $this->sync($this->ben['token'], [habitOp($id, $operation, 1, $payload)])->json('data.acks.0');
        expect([$ack['status'], $ack['error']['code']])->toBe(['rejected', 'not_found']);
    }

    $after = DB::table('habits')->where('id', $this->water)->first();
    expect([$after->name, $after->version, $after->archived_at])->toBe([$before->name, $before->version, $before->archived_at]);
    expect(DB::table('server_changes')->where('user_id', $this->ben['id'])->where('entity_type', 'habit')->count())->toBe(0);
})->with(['habit.update', 'habit.archive', 'habit.restore']);

it('never increments another user\'s habit', function () {
    $ack = $this->sync($this->ben['token'], [[
        'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit_log', 'entity_id' => (string) Str::uuid7(),
        'operation' => 'log.increment', 'base_version' => null, 'occurred_at' => '2026-05-28T17:22:00Z',
        'captured_timezone' => 'America/Los_Angeles', 'payload' => ['habit_id' => $this->water, 'delta' => '250.000'],
    ]])->json('data.acks.0');

    // The same answer as log.set_value on a habit this user does not have (yet).
    expect($ack['status'])->toBe('dependency_pending');
    expect(DB::table('habit_logs')->where('habit_id', $this->water)->count())->toBe(0);
});

it('keeps archived habits in the bootstrap and in the pull', function () {
    $this->sync($this->maya['token'], [habitOp($this->water, 'habit.archive', 1)])->assertJsonPath('data.acks.0.status', 'accepted');

    $bootstrap = $this->withToken($this->maya['token'])->getJson('/api/v1/sync/bootstrap')->assertOk()->json('data.habits');
    $habit = collect($bootstrap)->firstWhere('id', $this->water);
    expect($habit)->not->toBeNull('archived habits are bootstrapped')
        ->and($habit['archived_at'])->not->toBeNull();

    $change = collect($this->sync($this->maya['token'])->json('data.changes'))->last(fn ($c) => $c['entity'] === 'habit');
    expect($change['payload']['archived_at'])->not->toBeNull();
});
