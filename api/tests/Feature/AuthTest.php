<?php

use App\Models\PersonalAccessToken;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

beforeEach(fn () => $this->freezeClock('2026-05-28T17:22:00Z'));

function registration(array $overrides = []): array
{
    return [
        'name' => 'Maya Chen',
        'email' => 'maya.chen@example.com',
        'password' => 'correct horse battery staple',
        'timezone' => 'America/Los_Angeles',
        'device_name' => "Maya's phone",
        'device_id' => '01970000-0000-7000-8000-00000000d001',
        ...$overrides,
    ];
}

it('registers: 201, UUIDv7 user, token returned once, calendar entry and journal row', function () {
    $response = $this->postJson('/api/v1/auth/register', registration(['email' => '  Maya.Chen@Example.COM ']));

    $response->assertCreated()
        ->assertJsonPath('data.token_type', 'Bearer')
        ->assertJsonPath('data.user.email', 'maya.chen@example.com')
        ->assertJsonPath('data.user.timezone', 'America/Los_Angeles')
        ->assertJsonPath('data.user.xp', 0)
        ->assertJsonPath('data.user.level', 1)
        ->assertJsonPath('data.user.next_level_threshold', 100)
        ->assertJsonPath('meta.server_time', '2026-05-28T17:22:00Z');
    $userId = $response->json('data.user.id');
    expect($userId)->toMatch(UUID_V7_PATTERN)
        ->and($response->json('data.token'))->toMatch('/^[0-9a-f-]{36}\|.{48}$/')
        ->and($response->json('data.user'))->not->toHaveKey('password');

    $history = DB::table('user_timezone_history')->where('user_id', $userId)->get();
    expect($history)->toHaveCount(1)
        ->and(CarbonImmutable::parse($history[0]->effective_at)->utc()->format('c'))->toBe('2026-05-28T17:22:00+00:00');
    $change = DB::table('server_changes')->where('user_id', $userId)->first();
    expect([(int) $change->seq, $change->entity_type, $change->operation])->toBe([1, 'user', 'upsert']);
    expect(PersonalAccessToken::query()->first()?->device_id)->toBe('01970000-0000-7000-8000-00000000d001');
});

it('ignores server-owned fields sent by a client (invariant 1)', function () {
    $response = $this->postJson('/api/v1/auth/register', registration(['xp' => 9999, 'freeze_balance' => 2, 'id' => (string) Str::uuid7(), 'change_seq' => 50]));

    $response->assertCreated()->assertJsonPath('data.user.xp', 0)->assertJsonPath('data.user.freeze_balance', 0);
    expect((int) DB::table('users')->value('change_seq'))->toBe(1);
});

it('validates registration', function (array $overrides, string $field) {
    $this->postJson('/api/v1/auth/register', registration())->assertCreated();

    $this->postJson('/api/v1/auth/register', registration(['email' => 'other@example.com', ...$overrides]))
        ->assertStatus(422)
        ->assertJsonPath('error.code', 'validation_failed')
        ->assertJsonStructure(['error' => ['fields' => [$field]]]);
})->with([
    'password under 12 characters' => [['password' => 'elevenchars'], 'password'],
    'not an IANA zone' => [['timezone' => 'Mars/Olympus'], 'timezone'],
    'fixed offsets are not zones' => [['timezone' => '+02:00'], 'timezone'],
    'email already used (case-insensitive)' => [['email' => 'MAYA.CHEN@example.com'], 'email'],
]);

it('rejects a known-breached password (A16)', function () {
    config(['auth.password_breach_check' => true]);
    $password = 'password12345678';
    $sha1 = strtoupper(sha1($password));
    Http::fake(['api.pwnedpasswords.com/range/'.substr($sha1, 0, 5) => Http::response(substr($sha1, 5).":12345\r\nAAAA:1", 200)]);

    $this->postJson('/api/v1/auth/register', registration(['password' => $password]))
        ->assertStatus(422)
        ->assertJsonStructure(['error' => ['fields' => ['password']]]);
});

it('logs in with the same answer for an unknown email and a wrong password', function () {
    $this->postJson('/api/v1/auth/register', registration())->assertCreated();

    $wrong = $this->postJson('/api/v1/auth/login', ['email' => 'maya.chen@example.com', 'password' => 'not the password', 'device_name' => 'x']);
    $unknown = $this->postJson('/api/v1/auth/login', ['email' => 'nobody@example.com', 'password' => 'not the password', 'device_name' => 'x']);

    $wrong->assertStatus(422);
    expect($wrong->json('error'))->toBe($unknown->json('error'));

    $this->postJson('/api/v1/auth/login', ['email' => ' MAYA.CHEN@example.com', 'password' => 'correct horse battery staple', 'device_name' => 'tablet'])
        ->assertOk()
        ->assertJsonPath('data.user.email', 'maya.chen@example.com')
        ->assertJsonPath('meta.server_time', '2026-05-28T17:22:00Z');
});

it('authenticates UUID users with their token and returns A9 level fields on /me', function () {
    $user = $this->registerUser();

    $this->withToken($user['token'])->getJson('/api/v1/me')
        ->assertOk()
        ->assertJsonPath('data.id', $user['id'])
        ->assertJsonPath('data.level', 1)
        ->assertJsonPath('data.progress_into_level', 0)
        ->assertJsonPath('data.day_start_offset_minutes', 0);
});

it('logout revokes only this device; logout-all revokes every device', function () {
    $user = $this->registerUser(email: 'a@example.com');
    $second = $this->postJson('/api/v1/auth/login', ['email' => 'a@example.com', 'password' => 'correct horse battery staple', 'device_name' => 'tablet'])->json('data.token');

    $this->withToken($user['token'])->postJson('/api/v1/auth/logout')->assertNoContent();
    $this->app['auth']->forgetGuards();
    $this->withToken($user['token'])->getJson('/api/v1/me')->assertUnauthorized();
    $this->app['auth']->forgetGuards();
    $this->withToken($second)->getJson('/api/v1/me')->assertOk();

    $third = $this->postJson('/api/v1/auth/login', ['email' => 'a@example.com', 'password' => 'correct horse battery staple', 'device_name' => 'laptop'])->json('data.token');
    $this->app['auth']->forgetGuards();
    $this->withToken($third)->postJson('/api/v1/auth/logout-all')->assertNoContent();
    $this->app['auth']->forgetGuards();
    $this->withToken($second)->getJson('/api/v1/me')->assertUnauthorized();
    expect(PersonalAccessToken::query()->count())->toBe(0);
});

it('refresh rotates the token for the same device (A6)', function () {
    $user = $this->registerUser();
    $device = PersonalAccessToken::query()->sole()->device_id;

    $new = $this->withToken($user['token'])->postJson('/api/v1/auth/refresh')->assertOk()->json('data.token');

    $this->app['auth']->forgetGuards();
    $this->withToken($user['token'])->getJson('/api/v1/me')->assertUnauthorized();
    $this->app['auth']->forgetGuards();
    $this->withToken($new)->getJson('/api/v1/me')->assertOk();
    expect(PersonalAccessToken::query()->sole()->device_id)->toBe($device)->not->toBeNull();
});

it('expires tokens after 120 days (A6)', function () {
    $user = $this->registerUser();

    $this->travelTo(CarbonImmutable::parse('2026-05-28T17:22:00Z')->addDays(119));
    $this->withToken($user['token'])->getJson('/api/v1/me')->assertOk();

    $this->app['auth']->forgetGuards();
    $this->travelTo(CarbonImmutable::parse('2026-05-28T17:22:00Z')->addDays(121));
    $this->withToken($user['token'])->getJson('/api/v1/me')->assertUnauthorized();
});

it('answers malformed or forged tokens with 401, never a server error', function (string $token) {
    $this->registerUser();

    $this->withToken($token)->getJson('/api/v1/me')
        ->assertUnauthorized()
        ->assertJsonPath('error.code', 'unauthenticated');
})->with([
    'garbage' => ['garbage'],
    'non-UUID id' => ['not-a-uuid|secret'],
    'unknown UUID' => ['01970000-0000-7000-8000-000000000000|secret'],
    'empty secret' => ['01970000-0000-7000-8000-000000000000|'],
]);
