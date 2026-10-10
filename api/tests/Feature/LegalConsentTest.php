<?php

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

/*
 * A33: registration records which Terms and Privacy versions the user accepted
 * (contract-fixtures/auth/register_request.json). Stored, never returned.
 */

function registerBody(array $overrides = []): array
{
    $request = contractFixture('auth/register_request.json')['request'];
    $request['device_id'] = (string) Str::uuid7();

    return [...$request, ...$overrides];
}

it('stores the accepted versions and the server time of acceptance', function () {
    $this->freezeClock('2026-10-10T09:15:00Z');

    $this->postJson('/api/v1/auth/register', registerBody())->assertCreated();

    $row = DB::table('users')->where('email', 'maya.chen@example.com')->first();
    expect($row->terms_version)->toBe('2026-10-10')
        ->and($row->privacy_version)->toBe('2026-10-10')
        ->and(CarbonImmutable::parse($row->legal_accepted_at)->toIso8601ZuluString())->toBe('2026-10-10T09:15:00Z');
});

it('refuses a missing, malformed or impossible version, naming the field', function (string $field, mixed $value) {
    $body = registerBody();
    if ($value === null) {
        unset($body[$field]);
    } else {
        $body[$field] = $value;
    }

    $response = $this->postJson('/api/v1/auth/register', $body)->assertStatus(422);

    expect($response->json('error.code'))->toBe('validation_failed')
        ->and($response->json('error.fields'))->toHaveKey($field);
    expect(DB::table('users')->count())->toBe(0);
})->with([
    'terms missing' => ['terms_version', null],
    'privacy missing' => ['privacy_version', null],
    'terms malformed' => ['terms_version', '2026-10-1'],
    'privacy malformed' => ['privacy_version', 'v1'],
    'terms impossible date' => ['terms_version', '2026-02-30'],
    'privacy impossible date' => ['privacy_version', '2026-13-01'],
    'terms not a string' => ['terms_version', 20261010],
]);

it('never returns the versions: not in /me, the register response or the sync user entity', function () {
    $register = $this->postJson('/api/v1/auth/register', registerBody())->assertCreated();
    $token = (string) $register->json('data.token');
    $me = $this->withToken($token)->getJson('/api/v1/me')->assertOk();
    $changes = collect($this->sync($token)->json('data.changes'))->where('entity', 'user');

    foreach ([$register->getContent(), $me->getContent(), json_encode($changes->all())] as $body) {
        expect($body)->not->toContain('terms_version')
            ->not->toContain('privacy_version')
            ->not->toContain('legal_accepted_at');
    }
    expect($changes)->not->toBeEmpty();
});
