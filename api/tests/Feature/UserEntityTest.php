<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Phase 3b (A20): the user entity's fields in GET /me, the bootstrap and /sync changes
 * (contract-fixtures/sync/user_entity.json).
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->sync($this->maya['token'], [M::profileUpdate($this->maya['id'])]);
    DB::table('users')->where('id', $this->maya['id'])->update(['avatar_key' => 'avatars/'.$this->maya['id'].'/x-lg.webp', 'avatar_sha256' => str_repeat('a', 64)]);
});

/** @return list<array<string, mixed>> the user entity as each read path presents it */
function userEntities(object $test, string $token): array
{
    app('auth')->forgetGuards();
    $me = $test->withToken($token)->getJson('/api/v1/me')->assertOk()->json('data');
    app('auth')->forgetGuards();
    $bootstrap = $test->withToken($token)->getJson('/api/v1/sync/bootstrap')->assertOk()->json('data.user');
    $change = collect($test->sync($token)->json('data.changes'))->last(fn ($c) => $c['entity'] === 'user');

    return [$me, $bootstrap, $change['payload']];
}

it('presents every listed field and none of the private ones on every read path', function () {
    $fixture = syncFixtureFile('user_entity');

    foreach (userEntities($this, $this->maya['token']) as $i => $user) {
        expect($user)->toBeArray("read path {$i}");
        foreach ($fixture['fields'] as $field) {
            expect($user)->toHaveKey($field);
        }
        foreach ($fixture['never'] as $field) {
            expect($user)->not->toHaveKey($field);
        }
        expect(json_encode($user))->not->toContain('avatars/')->not->toContain(str_repeat('a', 64));
        expect([$user['city'], $user['country_code'], $user['avatar_version']])->toBe(['Accra', 'GH', 0]);
    }
    expect(array_keys($fixture['example_3b']))->toBe(['city', 'country_code', 'avatar_version']);
});
