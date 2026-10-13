<?php

use App\Domain\Freeze\FreezePolicy;
use App\Domain\Freeze\FreezePolicyVersion;
use App\Support\WireTime;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A39: reward_state is its own read-only entity, bootstrapped and journaled; the user entity no
 * longer carries the reward numbers. A42: profile.set_auto_freeze on the user entity.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($this->habit)])->assertOk();
});

it('bootstraps reward_state and pulls it again with a rising version when XP changes', function () {
    $fixture = syncFixtureFile('reward_state_entity');
    $entities = [];
    $next = null;
    do {
        app('auth')->forgetGuards();
        $page = $this->withToken($this->maya['token'])->getJson('/api/v1/sync/bootstrap?'.http_build_query(array_filter(['cursor' => $next])))->assertOk()->json('data');
        array_push($entities, ...$page['entities']);
        $next = $page['next_cursor'];
    } while ($page['has_more']);
    $cursor = (string) $page['sync_cursor'];
    $bootstrapped = collect($entities)->where('entity', 'reward_state')->sole();

    // The fixture's numbers are an example; the shape is the contract.
    expect(array_keys($bootstrapped))->toBe(array_keys($fixture['example']))
        ->and($bootstrapped['id'])->toBe($this->maya['id'])
        ->and($bootstrapped['version'])->toBe(1)
        ->and(collect($bootstrapped['payload'])->keys()->sort()->values()->all())->toBe(collect($fixture['fields'])->sort()->values()->all())
        ->and($bootstrapped['payload']['xp'])->toBe(0);

    $pull = $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0)], $cursor)->assertOk()->json('data');
    $pulled = collect($pull['changes'])->where('entity', 'reward_state')->values()->all();

    expect($pulled)->toHaveCount(1)
        ->and($pulled[0]['version'])->toBe(2)
        ->and($pulled[0]['payload']['xp'])->toBe(10)
        ->and($pulled[0]['payload']['level'])->toBe(1);
});

it('refuses a reward_state mutation with entity_read_only for an own, a foreign and a missing id', function () {
    $bob = $this->registerUser('Bob');
    $fixture = syncFixtureFile('reward_state_entity')['mutation'];
    $mutation = fn (string $id) => [
        'mutation_id' => (string) Str::uuid7(), 'entity' => 'reward_state', 'entity_id' => $id,
        'operation' => $fixture['request']['operation'], 'base_version' => 1, 'occurred_at' => '2026-05-28T17:20:00Z',
        'payload' => $fixture['request']['payload'],
    ];

    $acks = $this->sync($this->maya['token'], [$mutation($this->maya['id']), $mutation($bob['id']), $mutation((string) Str::uuid7())])->json('data.acks');

    foreach ($acks as $ack) {
        expect($ack['status'])->toBe($fixture['ack']['status'])->and($ack['error']['code'])->toBe($fixture['ack']['error']['code']);
    }
    expect(DB::table('users')->pluck('xp')->map(fn ($x) => (int) $x)->all())->toBe([0, 0]);
});

it('keeps the reward numbers off the user entity', function () {
    $never = ['xp', 'level', 'progress_into_level', 'next_level_threshold', 'freeze_balance'];
    app('auth')->forgetGuards();
    $me = $this->withToken($this->maya['token'])->getJson('/api/v1/me')->assertOk()->json('data');
    $user = collect($this->sync($this->maya['token'])->json('data.changes'))->firstWhere('entity', 'user')['payload'];

    foreach ($never as $field) {
        expect($user)->not->toHaveKey($field)
            ->and($me['user'] ?? $me)->not->toHaveKey($field);
    }
});

it('answers a stale set_auto_freeze with a version conflict and changes nothing', function () {
    $version = (int) DB::table('users')->where('id', $this->maya['id'])->value('version');

    $ack = $this->sync($this->maya['token'], [M::setAutoFreeze($this->maya['id'], true, $version - 1)])->json('data.acks.0');

    expect([$ack['status'], $ack['error']['code'], $ack['error']['current_version']])->toBe(['conflict', 'version_conflict', $version])
        ->and(DB::table('user_freeze_policy_versions')->count())->toBe(0)
        ->and((bool) DB::table('users')->where('id', $this->maya['id'])->value('auto_freeze'))->toBeFalse();
});

it('acknowledges an identical set_auto_freeze with no bump and no policy row', function () {
    $version = (int) DB::table('users')->where('id', $this->maya['id'])->value('version');
    $seq = (int) DB::table('users')->where('id', $this->maya['id'])->value('change_seq');

    $ack = $this->sync($this->maya['token'], [M::setAutoFreeze($this->maya['id'], false, $version)])->json('data.acks.0');

    expect([$ack['status'], $ack['version']])->toBe(['accepted', $version])
        ->and(DB::table('user_freeze_policy_versions')->count())->toBe(0)
        ->and((int) DB::table('users')->where('id', $this->maya['id'])->value('change_seq'))->toBe($seq);
});

it('takes effect at the server clock, not at occurred_at, and journals the user', function () {
    $version = (int) DB::table('users')->where('id', $this->maya['id'])->value('version');

    $ack = $this->sync($this->maya['token'], [M::setAutoFreeze($this->maya['id'], true, $version, '2026-05-01T08:00:00Z')])->json('data.acks.0');

    $policy = DB::table('user_freeze_policy_versions')->sole();
    $journal = DB::table('server_changes')->where('user_id', $this->maya['id'])->orderByDesc('seq')->first();
    expect([$ack['status'], $ack['version']])->toBe(['accepted', $version + 1])
        ->and($policy->effective_at)->toStartWith('2026-05-28 17:22:00')
        ->and((bool) $policy->enabled)->toBeTrue()
        ->and([$journal->entity_type, (int) $journal->version])->toBe(['user', $version + 1])
        ->and(json_decode($journal->payload, true)['auto_freeze'])->toBeTrue();
});

it('answers set_auto_freeze on another user like a missing one', function () {
    $bob = $this->registerUser('Bob');

    $acks = $this->sync($this->maya['token'], [
        M::setAutoFreeze($bob['id'], true, 1),
        M::setAutoFreeze((string) Str::uuid7(), true, 1),
    ])->json('data.acks');

    expect(array_column($acks, 'status'))->toBe(['rejected', 'rejected'])
        ->and(array_column(array_column($acks, 'error'), 'code'))->toBe(['not_found', 'not_found'])
        ->and((bool) DB::table('users')->where('id', $bob['id'])->value('auto_freeze'))->toBeFalse();
});

it('never ties two policy versions: on, off, on in one clock tick (5.1 review I3)', function () {
    foreach ([true, false, true] as $enabled) {
        $version = (int) DB::table('users')->where('id', $this->maya['id'])->value('version');
        expect($this->sync($this->maya['token'], [M::setAutoFreeze($this->maya['id'], $enabled, $version)])->json('data.acks.0.status'))->toBe('accepted');
    }

    $rows = DB::table('user_freeze_policy_versions')->orderBy('effective_at')->orderBy('id')->get();
    $times = $rows->map(fn ($r) => WireTime::parse((string) $r->effective_at)->getTimestamp())->all();
    expect($times[1])->toBeGreaterThan($times[0])
        ->and($times[2])->toBeGreaterThan($times[1])
        ->and($rows->pluck('enabled')->map(fn ($e) => (bool) $e)->all())->toBe([true, false, true]);

    // The policy in force at the last row's time is the last row's: on.
    $policy = new FreezePolicy($rows->map(fn ($r) => new FreezePolicyVersion((bool) $r->enabled, WireTime::parse((string) $r->effective_at)))->values()->all());
    expect($policy->enabledAt(WireTime::parse((string) $rows->last()->effective_at)))->toBeTrue();
});
