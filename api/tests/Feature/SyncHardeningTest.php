<?php

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Exceptions;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Phase 2a.1 (docs/reviews/PHASE_2A_REVIEW.md, A29). Ack shapes are checked against
 * contract-fixtures/sync/.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->user = $this->registerUser();
    $this->habit = (string) Str::uuid7();
});

function syncFixture(string $name): array
{
    return json_decode((string) file_get_contents(contractFixturePath("sync/{$name}.json")), true, flags: JSON_THROW_ON_ERROR);
}

// B1 ------------------------------------------------------------------------------------------

it('turns an unexpected failure in one mutation into a retryable ack; the batch continues (B1)', function () {
    Exceptions::fake();
    // Make the database fail for one specific habit, as an unforeseen bug would.
    DB::unprepared(<<<'SQL'
        CREATE FUNCTION boom() RETURNS trigger AS $$
        BEGIN
          IF NEW.name = 'BOOM' THEN RAISE EXCEPTION 'simulated failure'; END IF;
          RETURN NEW;
        END $$ LANGUAGE plpgsql;
        CREATE TRIGGER boom BEFORE INSERT ON habits FOR EACH ROW EXECUTE FUNCTION boom();
        SQL);
    $poison = M::habitCreate((string) Str::uuid7(), overrides: ['name' => 'BOOM']);

    $response = $this->sync($this->user['token'], [M::habitCreate($this->habit), $poison, M::habitCreate((string) Str::uuid7())]);

    $response->assertOk();
    $acks = $response->json('data.acks');
    expect(array_column($acks, 'status'))->toBe(['accepted', 'rejected', 'accepted']);
    assertMatchesContract(syncFixture('ack_server_error')['expect'], $acks[1]);
    expect(DB::table('mutation_receipts')->where('mutation_id', $poison['mutation_id'])->exists())->toBeFalse()
        ->and(DB::table('habits')->count())->toBe(2);
    Exceptions::assertReported(fn (QueryException $e) => str_contains($e->getMessage(), 'simulated failure'));

    // No receipt was stored, so once the cause is gone the same mutation is accepted.
    DB::unprepared('DROP TRIGGER boom ON habits; DROP FUNCTION boom();');
    $this->sync($this->user['token'], [$poison])->assertJsonPath('data.acks.0.status', 'accepted');
});

it('rejects out-of-range and malformed values in the ack, never with a 500 (B1)', function (string $type, mixed $value) {
    $habit = (string) Str::uuid7();
    $target = match ($type) {
        'binary' => 1,
        'quantity' => '1.000',
        default => 60,
    };
    $headers = ['X-Capabilities' => 'type.binary, type.quantity, type.duration'];
    $this->sync($this->user['token'], [M::habitCreate($habit, $type, $target, ['unit' => $type === 'quantity' ? 'mL' : null])], headers: $headers)
        ->assertJsonPath('data.acks.0.status', 'accepted');

    $this->sync($this->user['token'], [M::setValue($habit, $value, 0)])
        ->assertOk()
        ->assertJsonPath('data.acks.0.status', 'rejected')
        ->assertJsonPath('data.acks.0.error.code', 'invalid_value');
})->with([
    'quantity above numeric(12,3)' => ['quantity', '9999999999.000'],
    'quantity with 4 decimals' => ['quantity', '1.0001'],
    'quantity as a float' => ['quantity', 250.5],
    'duration over 25 hours' => ['duration', 100000],
    'negative duration' => ['duration', -1],
    'binary 2' => ['binary', 2],
]);

it('caps one mutation at 16 KB and 8 levels (A29)', function () {
    $big = M::habitCreate((string) Str::uuid7(), overrides: ['frequency_config' => ['pad' => str_repeat('x', 17000)]]);
    $deep = M::setValue($this->habit, 1, 0);
    $deep['payload']['detail'] = ['a' => ['b' => ['c' => ['d' => ['e' => ['f' => ['g' => 1]]]]]]];

    $acks = $this->sync($this->user['token'], [$big, $deep])->assertOk()->json('data.acks');

    expect($acks[0]['error']['code'])->toBe('payload_too_large')
        ->and($acks[1]['error']['code'])->toBe('validation_failed')
        ->and($acks[1]['error']['fields'])->toHaveKey('payload');
});

it('rejects over-long strings in the ack (B1)', function () {
    $acks = $this->sync($this->user['token'], [
        M::habitCreate((string) Str::uuid7(), overrides: ['name' => str_repeat('n', 101)]),
        M::habitCreate((string) Str::uuid7(), overrides: ['unit' => str_repeat('u', 25), 'type' => 'quantity', 'target_value' => '1.000']),
    ])->json('data.acks');

    expect($acks[0]['error']['fields'])->toHaveKey('name')
        ->and($acks[1]['error']['fields'])->toHaveKey('unit');
});

// B2 ------------------------------------------------------------------------------------------

it('restores a deleted day with the tombstone version; a stale edit still conflicts (B2)', function () {
    $this->sync($this->user['token'], [M::habitCreate($this->habit)]);
    $log = $this->sync($this->user['token'], [M::setValue($this->habit, 1, 0)])->json('data.acks.0.entity_id');
    $this->sync($this->user['token'], [M::delete($log, 1, $this->habit)])->assertJsonPath('data.acks.0.version', 2);

    // An edit queued before the delete (based on version 1) must not resurrect the day.
    $this->sync($this->user['token'], [M::setValue($this->habit, 1, 1)])
        ->assertJsonPath('data.acks.0.status', 'conflict')
        ->assertJsonPath('data.acks.0.error.code', 'resource_deleted')
        ->assertJsonPath('data.acks.0.error.current_version', 2);

    // The user saw the delete and logs the day again: base_version = tombstone version.
    $restore = $this->sync($this->user['token'], [M::setValue($this->habit, 1, 2, '2026-05-28T17:21:00Z')], deviceId: '01970000-0000-7000-8000-00000000d001');
    $ack = $restore->json('data.acks.0');
    assertMatchesContract(syncFixture('ack_restored')['expect'], $ack);
    expect($ack['entity_id'])->toBe($log);

    $row = DB::table('habit_logs')->where('id', $log)->first();
    expect($row->deleted_at)->toBeNull()->and((int) $row->version)->toBe(3)->and($row->completed_at)->not->toBeNull();

    // A second device pulling from the start sees create, delete, then the restore as an upsert.
    $logChanges = collect($this->sync($this->user['token'], deviceId: '01970000-0000-7000-8000-00000000d002')->json('data.changes'))
        ->where('entity', 'habit_log')->values();
    expect($logChanges->pluck('operation')->all())->toBe(['upsert', 'delete', 'upsert'])
        ->and($logChanges->last()['version'])->toBe(3)
        ->and($logChanges->last()['payload']['deleted_at'])->toBeNull();
});

// B3 ------------------------------------------------------------------------------------------

it('acks the canonical entity_id when two devices create the same habit-day (B3)', function () {
    $this->sync($this->user['token'], [M::habitCreate($this->habit)]);
    $first = $this->sync($this->user['token'], [M::setValue($this->habit, 1, 0)], deviceId: '01970000-0000-7000-8000-00000000d001')->json('data.acks.0');
    $secondMutation = M::setValue($this->habit, 1, 0);

    $second = $this->sync($this->user['token'], [$secondMutation], deviceId: '01970000-0000-7000-8000-00000000d002')->json('data.acks.0');

    assertMatchesContract(syncFixture('ack_merged_entity_id')['expect'], $second);
    expect($second['entity_id'])->not->toBe($secondMutation['entity_id'])
        ->and($second['entity_id'])->toBe($first['entity_id'])
        ->and(DB::table('habit_logs')->count())->toBe(1);
});

it('names the canonical row in a conflict ack, not the client id (B3)', function () {
    $this->sync($this->user['token'], [M::habitCreate($this->habit)]);
    $canonical = $this->sync($this->user['token'], [M::setValue($this->habit, 1, 0)])->json('data.acks.0.entity_id');

    $conflict = $this->sync($this->user['token'], [M::setValue($this->habit, 0, 0)])->json('data.acks.0');

    expect($conflict['status'])->toBe('conflict')
        ->and($conflict['entity_id'])->toBe($canonical)
        ->and($conflict['error']['resource_id'])->toBe($canonical);
});

it('deletes by habit_id + log_date when the log id is unknown to the server (B3)', function () {
    $this->sync($this->user['token'], [M::habitCreate($this->habit)]);
    $canonical = $this->sync($this->user['token'], [M::setValue($this->habit, 1, 0)])->json('data.acks.0.entity_id');
    $delete = M::delete((string) Str::uuid7(), 1, $this->habit);
    $delete['payload']['log_date'] = '2026-05-28';

    $ack = $this->sync($this->user['token'], [$delete])->json('data.acks.0');

    assertMatchesContract(syncFixture('ack_delete_natural_key')['expect'], $ack);
    expect($ack['entity_id'])->toBe($canonical)->not->toBe($delete['entity_id'])
        ->and(DB::table('habit_logs')->where('id', $canonical)->value('deleted_at'))->not->toBeNull();
});

it('keeps the natural-key fallback owner-scoped', function () {
    $other = $this->registerUser('Other');
    $this->sync($this->user['token'], [M::habitCreate($this->habit)]);
    $this->sync($this->user['token'], [M::setValue($this->habit, 1, 0)]);
    $delete = M::delete((string) Str::uuid7(), 1, $this->habit);
    $delete['payload']['log_date'] = '2026-05-28';

    $this->sync($other['token'], [$delete])->assertJsonPath('data.acks.0.error.code', 'not_found');
    expect(DB::table('habit_logs')->whereNotNull('deleted_at')->count())->toBe(0);
});

// S1 ------------------------------------------------------------------------------------------

it('answers 410 when a database restore leaves the cursor ahead of the journal (S1)', function () {
    $this->sync($this->user['token'], [M::habitCreate($this->habit), M::habitCreate((string) Str::uuid7())]);
    $cursor = $this->sync($this->user['token'])->json('data.next_cursor');

    // Restore from a backup taken before the last two changes.
    DB::table('server_changes')->where('user_id', $this->user['id'])->where('seq', '>', 1)->delete();
    DB::table('users')->where('id', $this->user['id'])->update(['change_seq' => 1]);

    $this->sync($this->user['token'], cursor: $cursor)->assertStatus(410)->assertJsonPath('error.code', 'cursor_expired');
});

it('answers 410 for cursors signed with a rotated app key (S1)', function () {
    $cursor = $this->sync($this->user['token'])->json('data.next_cursor');
    config(['app.key' => 'base64:'.base64_encode(random_bytes(32))]);

    $this->sync($this->user['token'], cursor: $cursor)->assertStatus(410);
});

// S2 ------------------------------------------------------------------------------------------

it('accepts a different captured zone when the hint matches; otherwise returns the server calendar (S2)', function () {
    $this->sync($this->user['token'], [M::habitCreate($this->habit)]);
    $agreeing = [...M::setValue($this->habit, 1, 0, capturedTimezone: 'Europe/Paris'), 'local_date_hint' => '2026-05-28'];
    $disagreeing = [...M::setValue($this->habit, 1, 0, capturedTimezone: 'Europe/Paris'), 'local_date_hint' => '2026-05-29'];

    $acks = $this->sync($this->user['token'], [$disagreeing, $agreeing])->json('data.acks');

    expect($acks[0]['error']['code'])->toBe('timezone_context_mismatch')
        ->and($acks[0]['error']['calendar']['timezone'])->toBe('America/Los_Angeles')
        ->and($acks[0]['error']['calendar']['day_start_offset_minutes'])->toBe(0)
        ->and($acks[1]['status'])->toBe('accepted')
        ->and($acks[1]['resolved_date'])->toBe('2026-05-28')
        ->and(DB::table('habit_logs')->value('resolved_timezone'))->toBe('America/Los_Angeles');
});

// S3 ------------------------------------------------------------------------------------------

it('stores and journals the canonical frequency_config, not the client object (S3)', function () {
    $response = $this->sync($this->user['token'], [M::habitCreate($this->habit, overrides: [
        'frequency_type' => 'weekdays',
        'frequency_config' => ['days' => [5, 1, 3], 'junk' => str_repeat('x', 100)],
    ])]);

    $response->assertJsonPath('data.acks.0.status', 'accepted');
    expect(json_decode((string) DB::table('habits')->value('frequency_config'), true))->toBe(['days' => [1, 3, 5]])
        ->and(json_decode((string) DB::table('habit_definition_versions')->value('frequency_config'), true))->toBe(['days' => [1, 3, 5]])
        ->and($response->json('data.changes.1.payload.frequency_config'))->toBe(['days' => [1, 3, 5]]);
});
