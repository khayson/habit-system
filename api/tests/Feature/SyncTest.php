<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->user = $this->registerUser();
    $this->habit = (string) Str::uuid7();
});

function seedBinaryHabit($test, string $habitId, string $start = '2026-05-28', string $dateMode = 'normal'): void
{
    $test->sync($test->user['token'], [M::habitCreate($habitId, overrides: ['start_local_date' => $start, 'date_mode' => $dateMode])])
        ->assertOk()->assertJsonPath('data.acks.0.status', 'accepted');
}

it('applies habit.create and log.set_value, then pulls the journal in seq order', function () {
    $response = $this->sync($this->user['token'], [
        M::habitCreate($this->habit),
        M::setValue($this->habit, 1, 0),
    ]);

    $response->assertOk()
        ->assertJsonPath('data.acks.0.status', 'accepted')
        ->assertJsonPath('data.acks.0.entity', 'habit')
        ->assertJsonPath('data.acks.0.version', 1)
        ->assertJsonPath('data.acks.1.status', 'accepted')
        ->assertJsonPath('data.acks.1.entity', 'habit_log')
        ->assertJsonPath('data.acks.1.resolved_date', '2026-05-28')
        ->assertJsonPath('data.acks.1.version', 1)
        ->assertJsonPath('data.has_more', false);

    $changes = $response->json('data.changes');
    expect(array_column($changes, 'seq'))->toBe([1, 2, 3])
        ->and(array_column($changes, 'entity'))->toBe(['user', 'habit', 'habit_log'])
        ->and($changes[1]['payload']['definitions'][0]['effective_date'])->toBe('2026-05-28')
        ->and($changes[1]['payload']['active_ranges'][0])->toBe(['starts_on' => '2026-05-28', 'ends_before' => null])
        ->and($changes[2]['payload']['value'])->toBe(1)
        ->and($changes[2]['payload']['completed_at'])->toBe('2026-05-28T17:15:00Z');
});

it('keeps quantities exact and durations whole on the wire (invariant 10)', function () {
    $water = (string) Str::uuid7();
    $response = $this->sync($this->user['token'], [
        M::habitCreate($water, 'quantity', '2000.000', ['unit' => 'mL', 'category' => 'health']),
        M::setValue($water, '1250.000', 0),
    ])->assertOk();

    expect($response->json('data.changes.1.payload.target_value'))->toBe('2000.000')
        ->and($response->json('data.changes.2.payload.value'))->toBe('1250.000')
        ->and($response->json('data.changes.2.payload.completed_at'))->toBeNull()
        ->and(DB::table('habit_logs')->value('value'))->toBe('1250.000');
});

it('duplicate retry of the same mutation applies once (spec 10)', function () {
    seedBinaryHabit($this, $this->habit);
    $mutation = M::setValue($this->habit, 1, 0);

    $first = $this->sync($this->user['token'], [$mutation])->assertOk();
    $journalBefore = DB::table('server_changes')->count();
    $retry = $this->sync($this->user['token'], [$mutation])->assertOk();

    expect($retry->json('data.acks.0'))->toBe([...$first->json('data.acks.0'), 'duplicate' => true])
        ->and(DB::table('habit_logs')->count())->toBe(1)
        ->and(DB::table('server_changes')->count())->toBe($journalBefore);
});

it('rejects the same mutation id with a changed payload (409 idempotency_mismatch shape)', function () {
    seedBinaryHabit($this, $this->habit);
    $mutation = M::setValue($this->habit, 1, 0);
    $this->sync($this->user['token'], [$mutation])->assertOk();

    $changed = [...$mutation, 'payload' => ['habit_id' => $this->habit, 'value' => 0]];
    $response = $this->sync($this->user['token'], [$changed])->assertOk();

    $response->assertJsonPath('data.acks.0.status', 'rejected')
        ->assertJsonPath('data.acks.0.error.code', 'idempotency_mismatch');
    expect(DB::table('habit_logs')->value('value'))->toBe('1.000');
});

it('hashes the original payload: key order does not matter, fractional seconds are kept', function () {
    seedBinaryHabit($this, $this->habit);
    $mutation = M::setValue($this->habit, 1, 0, occurredAt: '2026-05-28T17:15:00.123456Z');
    $this->sync($this->user['token'], [$mutation])->assertOk();

    $reordered = array_reverse($mutation, true);
    $this->sync($this->user['token'], [$reordered])->assertJsonPath('data.acks.0.duplicate', true);

    $truncated = [...$mutation, 'occurred_at' => '2026-05-28T17:15:00Z'];
    $this->sync($this->user['token'], [$truncated])->assertJsonPath('data.acks.0.error.code', 'idempotency_mismatch');
    $log = collect($this->sync($this->user['token'])->json('data.changes'))->firstWhere('entity', 'habit_log');
    expect($log['payload']['occurred_at'])->toBe('2026-05-28T17:15:00.123456Z');
});

it('three days offline resolve to three original local dates (spec 10)', function () {
    seedBinaryHabit($this, $this->habit, '2026-05-24', 'backdate');
    // The phone reconnects the next morning (UTC) and sends everything it queued.
    $this->freezeClock('2026-05-29T07:00:00Z');

    $response = $this->sync($this->user['token'], [
        M::setValue($this->habit, 1, 0, '2026-05-25T18:00:00Z'),
        M::setValue($this->habit, 1, 0, '2026-05-26T18:00:00Z'),
        M::setValue($this->habit, 1, 0, '2026-05-27T18:00:00Z'),
        // Spec 08: 06:30 UTC on 29 May is still 28 May in Pacific time.
        M::setValue($this->habit, 1, 0, '2026-05-29T06:30:00Z'),
    ]);

    expect(array_column($response->json('data.acks'), 'resolved_date'))->toBe(['2026-05-25', '2026-05-26', '2026-05-27', '2026-05-28'])
        ->and(DB::table('habit_logs')->orderBy('log_date')->pluck('log_date')->all())->toBe(['2026-05-25', '2026-05-26', '2026-05-27', '2026-05-28'])
        ->and(DB::table('habit_logs')->distinct()->pluck('resolved_timezone')->all())->toBe(['America/Los_Angeles']);
});

it('delete vs queued edit: 409-shaped resource_deleted with the tombstone version, no resurrection', function () {
    seedBinaryHabit($this, $this->habit);
    $log = $this->sync($this->user['token'], [M::setValue($this->habit, 1, 0)])->json('data.acks.0');

    // Device A deletes; device B still has a queued edit based on version 1.
    $this->sync($this->user['token'], [M::delete($log['entity_id'], 1, $this->habit)])
        ->assertJsonPath('data.acks.0.status', 'accepted')->assertJsonPath('data.acks.0.version', 2);
    $queued = $this->sync($this->user['token'], [M::setValue($this->habit, 0, 1)], deviceId: '01970000-0000-7000-8000-00000000d002');

    $queued->assertJsonPath('data.acks.0.status', 'conflict');
    expect($queued->json('data.acks.0.error'))->toBe([
        'code' => 'resource_deleted',
        'message' => 'This item was deleted on another device.',
        'entity' => 'habit_log',
        'resource_id' => $log['entity_id'],
        'current_version' => 2,
    ]);
    expect(DB::table('habit_logs')->whereNotNull('deleted_at')->count())->toBe(1);
    $deleteChange = collect($queued->json('data.changes'))->firstWhere('operation', 'delete');
    expect($deleteChange['version'])->toBe(2)->and($deleteChange['payload']['deleted_at'])->toBe('2026-05-28T17:22:00Z');
});

it('stale absolute edit conflicts with the canonical current value; identical intent is a no-op', function () {
    $water = (string) Str::uuid7();
    $this->sync($this->user['token'], [M::habitCreate($water, 'quantity', '2000.000', ['category' => 'health'])]);
    $log = $this->sync($this->user['token'], [M::setValue($water, '1500.000', 0)])->json('data.acks.0');
    $this->sync($this->user['token'], [M::setValue($water, '1750.000', 1)])->assertJsonPath('data.acks.0.version', 2);

    $stale = $this->sync($this->user['token'], [M::setValue($water, '1500.000', 1)]);
    $stale->assertJsonPath('data.acks.0.status', 'conflict')
        ->assertJsonPath('data.acks.0.error.code', 'version_conflict')
        ->assertJsonPath('data.acks.0.error.resource_id', $log['entity_id'])
        ->assertJsonPath('data.acks.0.error.expected_version', 1)
        ->assertJsonPath('data.acks.0.error.current_version', 2)
        ->assertJsonPath('data.acks.0.error.current.value', '1750.000');

    $same = $this->sync($this->user['token'], [M::setValue($water, '1750.000', 1)]);
    $same->assertJsonPath('data.acks.0.status', 'accepted')->assertJsonPath('data.acks.0.version', 2);
});

it('an interrupted pull replays safely: re-reading a cursor returns the same page', function () {
    seedBinaryHabit($this, $this->habit, '2026-05-20', 'backdate');
    $this->sync($this->user['token'], array_map(fn ($d) => M::setValue($this->habit, 1, 0, "2026-05-2{$d}T18:00:00Z"), [1, 2, 3, 4, 5]));

    $seen = [];
    $cursor = null;
    do {
        $page = $this->sync($this->user['token'], cursor: $cursor, pullLimit: 2)->assertOk();
        // The client crashed before saving the cursor: asking again returns the identical page.
        $again = $this->sync($this->user['token'], cursor: $cursor, pullLimit: 2)->assertOk();
        expect($again->json('data.changes'))->toBe($page->json('data.changes'));

        array_push($seen, ...array_column($page->json('data.changes'), 'seq'));
        $cursor = $page->json('data.next_cursor');
    } while ($page->json('data.has_more'));

    expect($seen)->toBe(range(1, 7));
    expect($this->sync($this->user['token'], cursor: $cursor)->json('data.changes'))->toBe([]);
});

it('expires cursors that are tampered, from another user, or unusable (A29)', function () {
    $other = $this->registerUser('Other');
    $foreign = $this->sync($other['token'])->json('data.next_cursor');
    $mine = $this->sync($this->user['token'])->json('data.next_cursor');
    [$payload, $signature] = explode('.', $mine);
    $tampered = rtrim(strtr(base64_encode(json_encode(['v' => 1, 't' => 's', 'u' => $this->user['id'], 's' => 999])), '+/', '-_'), '=').'.'.$signature;

    // A29: every cursor that cannot be honoured is 410 cursor_expired (the client bootstraps).
    foreach ([$foreign, $tampered, 'not-a-cursor'] as $cursor) {
        $this->sync($this->user['token'], [M::habitCreate((string) Str::uuid7())], cursor: $cursor)
            ->assertStatus(410)
            ->assertJsonPath('error.code', 'cursor_expired');
    }
    // Only a malformed parameter is invalid input.
    $this->sync($this->user['token'], cursor: str_repeat('x', 2000))->assertStatus(422)->assertJsonStructure(['error' => ['fields' => ['cursor']]]);
    // A rejected request applies nothing.
    expect(DB::table('habits')->count())->toBe(0);
});

it('caps a batch at 100 mutations with 413 and applies none', function () {
    $mutations = array_map(fn () => M::habitCreate((string) Str::uuid7()), range(1, 101));

    $this->sync($this->user['token'], $mutations)->assertStatus(413)->assertJsonPath('error.code', 'payload_too_large');
    expect(DB::table('habits')->count())->toBe(0);
});

it('rejects one malformed mutation in its ack while the rest of the batch applies', function () {
    $bad = M::habitCreate((string) Str::uuid7());
    unset($bad['occurred_at']);

    $response = $this->sync($this->user['token'], [$bad, M::habitCreate($this->habit)]);

    $response->assertOk()
        ->assertJsonPath('data.acks.0.status', 'rejected')
        ->assertJsonPath('data.acks.0.error.code', 'validation_failed')
        ->assertJsonStructure(['data' => ['acks' => [['error' => ['fields' => ['occurred_at']]]]]])
        ->assertJsonPath('data.acks.1.status', 'accepted');
});

it('normalises spec aliases per type and stores the canonical name (A27)', function () {
    seedBinaryHabit($this, $this->habit);
    $alias = M::setValue($this->habit, 1, 0, operation: 'log.set_binary');
    $wrong = M::setValue($this->habit, 1, 0, operation: 'log.increment_quantity');

    $response = $this->sync($this->user['token'], [$alias, $wrong]);

    $response->assertJsonPath('data.acks.0.status', 'accepted')
        ->assertJsonPath('data.acks.1.status', 'rejected')
        ->assertJsonPath('data.acks.1.error.code', 'unsupported_operation');
    expect(DB::table('mutation_receipts')->where('mutation_id', $alias['mutation_id'])->value('operation'))->toBe('log.set_value');
});

it('returns dependency_pending for a log before its habit, stores no receipt, and accepts the retry later', function () {
    $log = M::setValue($this->habit, 1, 0);

    $this->sync($this->user['token'], [$log])->assertJsonPath('data.acks.0.status', 'dependency_pending');
    expect(DB::table('mutation_receipts')->where('mutation_id', $log['mutation_id'])->exists())->toBeFalse();

    $this->sync($this->user['token'], [M::habitCreate($this->habit), $log])
        ->assertJsonPath('data.acks.1.status', 'accepted');
});

it('only creates types the client declared in X-Capabilities (A21)', function () {
    $this->sync($this->user['token'], [M::habitCreate($this->habit, 'quantity', '20.000')], headers: ['X-Capabilities' => 'type.binary'])
        ->assertJsonPath('data.acks.0.status', 'rejected')
        ->assertJsonPath('data.acks.0.error.code', 'unsupported_type');

    $this->sync($this->user['token'], [M::habitCreate((string) Str::uuid7(), 'checklist', 3)])
        ->assertJsonPath('data.acks.0.error.code', 'unsupported_type');
});

it('maps domain date errors into acks: future events, inactive dates, past starts', function () {
    seedBinaryHabit($this, $this->habit);

    $response = $this->sync($this->user['token'], [
        M::setValue($this->habit, 1, 0, '2026-05-28T17:28:00Z'),
        M::setValue($this->habit, 1, 0, '2026-05-27T18:00:00Z'),
        M::setValue($this->habit, 1, 0, capturedTimezone: 'Europe/Paris'),
        M::habitCreate((string) Str::uuid7(), overrides: ['start_local_date' => '2026-05-20']),
        M::habitCreate((string) Str::uuid7(), overrides: ['start_local_date' => '2026-04-01', 'date_mode' => 'backdate']),
    ]);

    expect(array_map(fn ($a) => $a['error']['code'] ?? $a['status'], $response->json('data.acks')))
        ->toBe(['future_event', 'validation_failed', 'timezone_context_mismatch', 'validation_failed', 'backdate_too_old']);
    expect($response->json('data.acks.1.error.fields'))->toHaveKey('occurred_at');
});

it('never takes owner, version or reward fields from a client payload (invariant 1)', function () {
    $other = $this->registerUser('Other');
    $mutation = M::habitCreate($this->habit, overrides: ['user_id' => $other['id'], 'version' => 99, 'xp' => 500]);

    $this->sync($this->user['token'], [$mutation])->assertJsonPath('data.acks.0.version', 1);

    $habit = DB::table('habits')->where('id', $this->habit)->first();
    expect($habit->user_id)->toBe($this->user['id'])->and((int) $habit->version)->toBe(1);
});
