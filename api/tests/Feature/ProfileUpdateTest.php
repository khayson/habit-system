<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Phase 3b (A20): profile.update through the MutationApplier (invariant 4), against
 * contract-fixtures/sync/profile_update_mutations.json.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
});

/** The fixture's expectation with {{user_id}} replaced by $userId. */
function withUserId(mixed $expected, string $userId): mixed
{
    return json_decode(str_replace('{{user_id}}', $userId, (string) json_encode($expected)), true);
}

function profileAck(object $test, string $token, array $mutation): array
{
    return $test->sync($token, [$mutation])->json('data.acks.0');
}

/** @return array{string|null, string|null, string|null, int} */
function profileRow(string $userId): array
{
    $row = DB::table('users')->where('id', $userId)->first();

    return [$row->name, $row->city, $row->country_code, (int) $row->version];
}

it('accepts the fixture update, bumps the version and journals the user', function () {
    $fixture = syncFixtureFile('profile_update_mutations')['accepted'];

    $ack = profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id']));

    assertMatchesContract(withUserId($fixture['expect'], $this->maya['id']), $ack);
    expect(profileRow($this->maya['id']))->toBe(['Maya Chen', 'Accra', 'GH', 2]);
    $change = collect($this->sync($this->maya['token'])->json('data.changes'))->last(fn ($c) => $c['entity'] === 'user');
    expect($change['version'])->toBe(2)->and($change['payload']['name'])->toBe('Maya Chen');
});

it('answers a stale base version with a conflict carrying the current version', function () {
    $fixture = syncFixtureFile('profile_update_mutations')['version_conflict'];
    profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id']));

    $ack = profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id'], 'version_conflict'));

    expect([$ack['status'], $ack['entity'], $ack['error']['code'], $ack['error']['current_version']])
        ->toBe([$fixture['expect']['status'], $fixture['expect']['entity'], $fixture['expect']['error_code'], $fixture['after_version']]);
    expect(profileRow($this->maya['id']))->toBe(['Maya Chen', 'Accra', 'GH', 2], 'unchanged');
});

it('rejects the fixture\'s invalid fields by name', function () {
    $fixture = syncFixtureFile('profile_update_mutations')['validation_failed'];

    $ack = profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id'], 'validation_failed'));

    expect([$ack['status'], $ack['error']['code']])->toBe([$fixture['expect']['status'], $fixture['expect']['error_code']])
        ->and(array_keys($ack['error']['fields']))->toEqualCanonicalizing($fixture['expect']['fields']);
    expect(profileRow($this->maya['id']))->toBe(['Maya', null, null, 1]);
});

it('answers another user\'s id or a missing one with not_found', function () {
    $ben = $this->registerUser('Ben');

    foreach ([$ben['id'], (string) Str::uuid7()] as $id) {
        $ack = profileAck($this, $this->maya['token'], M::profileUpdate($id));
        expect([$ack['status'], $ack['error']['code']])->toBe(['rejected', 'not_found']);
    }
    expect(profileRow($ben['id']))->toBe(['Ben', null, null, 1]);
});

it('acknowledges an identical update without a new version', function () {
    profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id']));
    $seq = DB::table('users')->where('id', $this->maya['id'])->value('change_seq');

    $ack = profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id'], baseVersion: 2));

    expect([$ack['status'], $ack['version']])->toBe(['accepted', 2])
        ->and(DB::table('users')->where('id', $this->maya['id'])->value('change_seq'))->toBe($seq, 'nothing journaled');
});

it('trims the city, clears empty or null fields, and refuses control characters and unknown codes', function () {
    profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id'], payload: ['city' => '  Kumasi  ']));
    expect(profileRow($this->maya['id']))->toBe(['Maya Chen', 'Kumasi', 'GH', 2]);

    profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id'], baseVersion: 2, payload: ['city' => '   ', 'country_code' => null]));
    expect(profileRow($this->maya['id']))->toBe(['Maya Chen', null, null, 3]);

    foreach ([['city' => "Ac\u{0007}cra"], ['country_code' => 'EU'], ['country_code' => 'ZZ'], ['city' => str_repeat('a', 61)]] as $bad) {
        $ack = profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id'], baseVersion: 3, payload: $bad));
        expect($ack['error']['code'])->toBe('validation_failed')
            ->and(array_keys($ack['error']['fields']))->toBe(array_keys($bad));
    }
    expect(profileRow($this->maya['id']))->toBe(['Maya Chen', null, null, 3]);
});

it('requires every field of the desired state and a base version', function () {
    $m = M::profileUpdate($this->maya['id']);
    unset($m['payload']['city']);
    expect(profileAck($this, $this->maya['token'], $m)['error']['fields'])->toHaveKey('city');

    $ack = profileAck($this, $this->maya['token'], [...M::profileUpdate($this->maya['id']), 'base_version' => null]);
    expect($ack['error']['fields'])->toHaveKey('base_version');
});

it('writes the journal row in the same transaction as the profile', function () {
    DB::unprepared(<<<'SQL'
        CREATE FUNCTION no_user_journal() RETURNS trigger AS $$
        BEGIN
            IF NEW.entity_type = 'user' THEN
                RAISE EXCEPTION 'journal down';
            END IF;
            RETURN NEW;
        END $$ LANGUAGE plpgsql;
        CREATE TRIGGER no_user_journal BEFORE INSERT ON server_changes
            FOR EACH ROW EXECUTE FUNCTION no_user_journal();
        SQL);

    $ack = profileAck($this, $this->maya['token'], M::profileUpdate($this->maya['id']));

    expect($ack['status'])->toBe('rejected')->and($ack['error']['retryable'])->toBeTrue();
    expect(profileRow($this->maya['id']))->toBe(['Maya', null, null, 1]);
});
