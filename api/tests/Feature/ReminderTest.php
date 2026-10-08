<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Phase 3.2b: reminders as a synced entity (contract-fixtures/sync/reminder_mutations.json and
 * reminder_entity.json). Owner-scoped, version-checked, idempotent, journaled with the write.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($this->habit)])->assertJsonPath('data.acks.0.status', 'accepted');
    $this->reminder = (string) Str::uuid7();
});

function ack(object $test, string $token, array $mutation): array
{
    return $test->sync($token, [$mutation])->json('data.acks.0');
}

/** @return list<array<string, mixed>> every bootstrap entity of type reminder */
function reminderBootstrapEntities(object $test, string $token, int $limit): array
{
    $entities = [];
    $cursor = null;
    do {
        $page = $test->withToken($token)->getJson('/api/v1/sync/bootstrap?'.http_build_query(array_filter(['limit' => $limit, 'cursor' => $cursor])))
            ->assertOk()->json('data');
        $entities = [...$entities, ...array_filter($page['entities'], fn (array $e) => $e['entity'] === 'reminder')];
        $cursor = $page['next_cursor'];
    } while ($page['has_more']);

    return array_values($entities);
}

function reminderChanges(object $test, string $token): array
{
    return collect($test->sync($token, deviceId: (string) Str::uuid7())->json('data.changes'))
        ->where('entity', 'reminder')->values()->all();
}

it('creates, updates and deletes as the fixture says, journaling each write', function () {
    $fixture = syncFixtureFile('reminder_mutations');
    $create = M::reminder('create', $this->reminder, $this->habit);
    assertMatchesContract($fixture['create']['expect'], ack($this, $this->maya['token'], $create));
    assertMatchesContract($fixture['update']['expect'], ack($this, $this->maya['token'], M::reminder('update', $this->reminder, baseVersion: 1)));
    assertMatchesContract($fixture['delete']['expect'], ack($this, $this->maya['token'], M::reminder('delete', $this->reminder, baseVersion: 2)));

    $row = DB::table('reminders')->where('id', $this->reminder)->first();
    expect($row->deleted_at)->not->toBeNull()->and((int) $row->version)->toBe(3)
        ->and(substr((string) $row->local_time, 0, 5))->toBe('07:30');

    $changes = reminderChanges($this, $this->maya['token']);
    expect(array_column($changes, 'operation'))->toBe(['upsert', 'upsert', 'delete'])
        ->and(array_column($changes, 'version'))->toBe([1, 2, 3]);
    $entity = syncFixtureFile('reminder_entity');
    assertMatchesContract($entity['change'], $changes[0]);
    assertMatchesContract($entity['tombstone'], $changes[2]);
});

it('stores days sorted and refuses malformed fields', function () {
    $ack = ack($this, $this->maya['token'], M::reminder('create', $this->reminder, $this->habit, payload: ['days_of_week' => [5, 1, 3]]));
    expect($ack['status'])->toBe('accepted');
    expect(json_decode((string) DB::table('reminders')->value('days_of_week'), true))->toBe([1, 3, 5]);

    foreach ([
        ['local_time' => '8:00'], ['local_time' => '24:00'], ['days_of_week' => []], ['days_of_week' => [1, 1]],
        ['days_of_week' => [0]], ['timezone_mode' => 'utc'], ['timezone' => 'Mars/Olympus'],
    ] as $bad) {
        $rejected = ack($this, $this->maya['token'], M::reminder('create', (string) Str::uuid7(), $this->habit, payload: $bad));
        expect($rejected['status'])->toBe('rejected')->and($rejected['error']['code'])->toBe('validation_failed');
    }
    expect(DB::table('reminders')->count())->toBe(1);
});

it('answers a stale base with version_conflict and the current reminder', function () {
    ack($this, $this->maya['token'], M::reminder('create', $this->reminder, $this->habit));
    ack($this, $this->maya['token'], M::reminder('update', $this->reminder, baseVersion: 1));

    $stale = ack($this, $this->maya['token'], M::reminder('update', $this->reminder, baseVersion: 1, payload: ['local_time' => '06:00']));

    expect($stale['status'])->toBe('conflict')
        ->and($stale['error']['code'])->toBe('version_conflict')
        ->and($stale['error']['current']['local_time'])->toBe('07:30');
    expect((int) DB::table('reminders')->value('version'))->toBe(2);
});

it('replays the same mutation as a duplicate and refuses the same id with another payload', function () {
    $create = M::reminder('create', $this->reminder, $this->habit);
    $first = ack($this, $this->maya['token'], $create);
    $again = ack($this, $this->maya['token'], $create);
    expect($again)->toBe([...$first, 'duplicate' => true]);

    $changed = $create;
    $changed['payload']['local_time'] = '09:00';
    $mismatch = ack($this, $this->maya['token'], $changed);
    expect($mismatch['error']['code'])->toBe('idempotency_mismatch');
    expect(DB::table('reminders')->count())->toBe(1)->and(DB::table('server_changes')->where('entity_type', 'reminder')->count())->toBe(1);
});

it('acks an identical update without a new version', function () {
    ack($this, $this->maya['token'], M::reminder('create', $this->reminder, $this->habit));
    $fixture = syncFixtureFile('reminder_mutations')['create']['mutation']['payload'];
    unset($fixture['habit_id']);

    $same = ack($this, $this->maya['token'], M::reminder('update', $this->reminder, baseVersion: 1, payload: $fixture));

    expect($same['status'])->toBe('accepted')->and($same['version'])->toBe(1);
    expect(DB::table('server_changes')->where('entity_type', 'reminder')->count())->toBe(1);
});

it('keeps a deleted reminder deleted; a new one takes a new id', function () {
    ack($this, $this->maya['token'], M::reminder('create', $this->reminder, $this->habit));
    ack($this, $this->maya['token'], M::reminder('delete', $this->reminder, baseVersion: 1));

    foreach ([M::reminder('update', $this->reminder, baseVersion: 2), M::reminder('delete', $this->reminder, baseVersion: 2), M::reminder('create', $this->reminder, $this->habit)] as $m) {
        $ack = ack($this, $this->maya['token'], $m);
        expect($ack['status'])->toBe('conflict')->and($ack['error']['code'])->toBe('resource_deleted');
    }

    $recreated = (string) Str::uuid7();
    expect(ack($this, $this->maya['token'], M::reminder('create', $recreated, $this->habit))['status'])->toBe('accepted');
    expect(DB::table('reminders')->whereNull('deleted_at')->pluck('id')->all())->toBe([$recreated]);
});

it('treats another owner\'s reminder or habit exactly like a missing one', function () {
    ack($this, $this->maya['token'], M::reminder('create', $this->reminder, $this->habit));
    $ana = $this->registerUser('Ana');

    // A foreign habit: the same answer as a habit that has not arrived yet.
    $foreignHabit = ack($this, $ana['token'], M::reminder('create', (string) Str::uuid7(), $this->habit));
    $missingHabit = ack($this, $ana['token'], M::reminder('create', (string) Str::uuid7(), (string) Str::uuid7()));
    expect($foreignHabit['status'])->toBe('dependency_pending')->and($missingHabit['status'])->toBe('dependency_pending');

    // A foreign reminder id: create, update and delete all answer like a missing id.
    foreach (['create', 'update', 'delete'] as $step) {
        $missing = (string) Str::uuid7();
        $anaHabit = (string) Str::uuid7();
        $this->sync($ana['token'], [M::habitCreate($anaHabit)]);
        $foreign = ack($this, $ana['token'], M::reminder($step, $this->reminder, $anaHabit, 1));
        $unknown = ack($this, $ana['token'], M::reminder($step, $missing, $anaHabit, 1));
        if ($step === 'create') {
            expect($foreign['error']['code'])->toBe('not_found');
        } else {
            expect([$foreign['status'], $foreign['error']['code']])->toBe([$unknown['status'], $unknown['error']['code']])
                ->and($foreign['error']['code'])->toBe('not_found');
        }
        expect(json_encode($foreign))->not->toContain('08:00');
    }

    $row = DB::table('reminders')->where('id', $this->reminder)->first();
    expect((int) $row->version)->toBe(1)->and($row->deleted_at)->toBeNull();
    expect(array_column(reminderChanges($this, $ana['token']), 'id'))->not->toContain($this->reminder);
    expect(array_column(reminderBootstrapEntities($this, $ana['token'], 50), 'id'))->not->toContain($this->reminder);
});

it('bootstraps reminders, tombstones included, through entities', function () {
    ack($this, $this->maya['token'], M::reminder('create', $this->reminder, $this->habit));
    $gone = (string) Str::uuid7();
    ack($this, $this->maya['token'], M::reminder('create', $gone, $this->habit));
    ack($this, $this->maya['token'], M::reminder('delete', $gone, baseVersion: 1));

    $reminders = collect(reminderBootstrapEntities($this, $this->maya['token'], 1))->keyBy('id');

    expect($reminders->keys()->sort()->values()->all())->toBe(collect([$this->reminder, $gone])->sort()->values()->all())
        ->and($reminders[$gone]['payload']['deleted_at'])->not->toBeNull()
        ->and($reminders[$gone]['version'])->toBe(2);
});

it('writes the journal row in the same transaction as the reminder', function () {
    ack($this, $this->maya['token'], M::reminder('create', $this->reminder, $this->habit));
    // The journal insert for the delete fails: the tombstone must not land without it.
    DB::unprepared(<<<'SQL'
        CREATE FUNCTION no_reminder_delete_journal() RETURNS trigger AS $$
        BEGIN
            IF NEW.entity_type = 'reminder' AND NEW.operation = 'delete' THEN
                RAISE EXCEPTION 'journal down';
            END IF;
            RETURN NEW;
        END $$ LANGUAGE plpgsql;
        CREATE TRIGGER no_reminder_delete_journal BEFORE INSERT ON server_changes
            FOR EACH ROW EXECUTE FUNCTION no_reminder_delete_journal();
        SQL);

    $ack = ack($this, $this->maya['token'], M::reminder('delete', $this->reminder, baseVersion: 1));

    expect($ack['status'])->toBe('rejected')->and($ack['error']['retryable'])->toBeTrue();
    $row = DB::table('reminders')->where('id', $this->reminder)->first();
    expect($row->deleted_at)->toBeNull()->and((int) $row->version)->toBe(1);
});
