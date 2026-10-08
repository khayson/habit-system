<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * D1 / A26: profile.set_timezone through the MutationApplier (invariant 4).
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
});

/** @return list<array{timezone: string, effective_at: string}> */
function calendarRows(string $userId): array
{
    return DB::table('user_timezone_history')->where('user_id', $userId)->orderBy('effective_at')
        ->get(['timezone', 'effective_at'])
        ->map(fn ($r) => ['timezone' => $r->timezone, 'effective_at' => (new DateTimeImmutable($r->effective_at))->format('Y-m-d\TH:i:s\Z')])->all();
}

it('schedules the new zone for the next local day start, bumps the version and journals the user', function () {
    $ack = $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'Europe/Paris', 1)])->json('data.acks.0');

    expect($ack)->toMatchArray(['status' => 'accepted', 'entity' => 'user', 'entity_id' => $this->maya['id'], 'version' => 2]);
    expect(calendarRows($this->maya['id']))->toBe([
        ['timezone' => 'America/Los_Angeles', 'effective_at' => '2026-05-28T17:22:00Z'],
        ['timezone' => 'Europe/Paris', 'effective_at' => '2026-05-29T07:00:00Z'],
    ]);

    $change = collect($this->sync($this->maya['token'])->json('data.changes'))->last(fn ($c) => $c['entity'] === 'user');
    expect($change['version'])->toBe(2)
        ->and($change['payload']['timezone'])->toBe('America/Los_Angeles', 'still the zone in force now')
        ->and($change['payload']['version'])->toBe(2)
        // jsonb reorders object keys, so compare by value.
        ->and($change['payload']['calendar_history'])->toEqual([
            ['timezone' => 'America/Los_Angeles', 'day_start_offset_minutes' => 0, 'effective_at' => '2026-05-28T17:22:00Z'],
            ['timezone' => 'Europe/Paris', 'day_start_offset_minutes' => 0, 'effective_at' => '2026-05-29T07:00:00Z'],
        ]);
});

it('replaces a pending change, and changing back cancels it', function () {
    $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'Europe/Paris', 1)]);
    $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'Asia/Tokyo', 2)]);
    expect(array_column(calendarRows($this->maya['id']), 'timezone'))->toBe(['America/Los_Angeles', 'Asia/Tokyo']);

    $ack = $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'America/Los_Angeles', 3)])->json('data.acks.0');
    expect($ack['version'])->toBe(4)
        ->and(array_column(calendarRows($this->maya['id']), 'timezone'))->toBe(['America/Los_Angeles']);
});

it('acknowledges the zone already in force without a new version', function () {
    $ack = $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'America/Los_Angeles', 1)])->json('data.acks.0');

    expect($ack)->toMatchArray(['status' => 'accepted', 'version' => 1]);
    expect(DB::table('server_changes')->where('user_id', $this->maya['id'])->where('entity_type', 'user')->count())->toBe(1, 'only the registration row');
});

it('takes effect at the boundary: the user entity reports the new zone once it is in force', function () {
    $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'Europe/Paris', 1)]);
    $this->freezeClock('2026-05-29T07:00:00Z');

    $me = $this->withToken($this->maya['token'])->getJson('/api/v1/me')->json('data');
    expect($me['timezone'])->toBe('Europe/Paris');
});

it('conflicts on a stale base_version with the current user', function () {
    $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'Europe/Paris', 1)]);

    $ack = $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'Asia/Tokyo', 1)])->json('data.acks.0');

    expect($ack['status'])->toBe('conflict')
        ->and($ack['error']['code'])->toBe('version_conflict')
        ->and($ack['error']['current_version'])->toBe(2)
        ->and($ack['error']['current']['id'])->toBe($this->maya['id']);
});

it('rejects a zone that is not IANA', function (string $zone) {
    $ack = $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], $zone, 1)])->json('data.acks.0');

    expect($ack['error']['code'])->toBe('validation_failed')
        ->and($ack['error']['fields'])->toHaveKey('timezone');
    expect(DB::table('user_timezone_history')->where('user_id', $this->maya['id'])->count())->toBe(1);
})->with(['+02:00', 'PST', 'Mars/Olympus']);

it('answers another user\'s id exactly like a missing one', function () {
    $bob = $this->registerUser('Bob');

    $foreign = $this->sync($this->maya['token'], [M::setTimezone($bob['id'], 'Europe/Paris', 1)])->json('data.acks.0');
    $missing = $this->sync($this->maya['token'], [M::setTimezone((string) Str::uuid7(), 'Europe/Paris', 1)])->json('data.acks.0');

    unset($foreign['mutation_id'], $foreign['entity_id'], $missing['mutation_id'], $missing['entity_id']);
    expect($foreign)->toBe($missing)
        ->and($foreign['error'])->toBe(['code' => 'not_found', 'message' => 'Not found.']);
    expect(DB::table('user_timezone_history')->where('user_id', $bob['id'])->count())->toBe(1);
});
