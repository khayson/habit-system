<?php

use App\Application\Accounts\AccountPurger;
use App\Application\Avatars\AvatarStore;
use App\Application\Exports\ExportStore;
use App\Application\Periods\PeriodCloser;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A49: DELETE /me, the status receipt and the purge, against contract-fixtures/auth/delete_me.json
 * and account_deletion_status.json. The queue runs synchronously in tests unless faked.
 */

beforeEach(function () {
    Storage::fake('local');
    $this->freezeClock('2026-05-28T17:22:00Z');
});

function deleteMeFixture(): array
{
    return contractFixture('auth/delete_me.json');
}

/** A user whose password is the fixture's, with a second session on another device. */
function deletableUser(object $test, string $email = 'maya.chen@example.com'): array
{
    $password = deleteMeFixture()['request']['password'];
    $body = ['name' => 'Maya Chen', 'email' => $email, 'password' => $password, 'timezone' => 'America/Los_Angeles',
        'terms_version' => '2026-10-24', 'privacy_version' => '2026-10-24'];
    app('auth')->forgetGuards();
    $first = $test->postJson('/api/v1/auth/register', [...$body, 'device_name' => 'phone', 'device_id' => (string) Str::uuid7()])->assertCreated();
    app('auth')->forgetGuards();
    $second = $test->postJson('/api/v1/auth/login', ['email' => $email, 'password' => $password, 'device_name' => 'tablet', 'device_id' => (string) Str::uuid7()])->assertOk();

    return ['id' => (string) $first->json('data.user.id'), 'token' => (string) $first->json('data.token'),
        'other' => (string) $second->json('data.token'), 'email' => $email, 'password' => $password];
}

function asUser(object $test, ?string $token, string $method, string $path, array $body = []): TestResponse
{
    app('auth')->forgetGuards();
    $test->flushHeaders();

    return ($token === null ? $test : $test->withToken($token))->json($method, '/api/v1'.$path, $body);
}

function statusWith(object $test, ?string $receipt, string $id): TestResponse
{
    return asUser($test, $receipt, 'GET', "/account-deletions/{$id}");
}

/** Gives the user a row in as many owned tables as the real flows reach. */
function populate(object $test, array $user): string
{
    $habit = (string) Str::uuid7();
    $test->sync($user['token'], [
        M::habitCreate($habit, 'binary', 1, ['start_local_date' => '2026-05-20', 'date_mode' => 'backdate']),
        M::setValue($habit, 1, 0, '2026-05-21T18:00:00Z'),
        M::setValue($habit, 1, 0, '2026-05-28T17:00:00Z'),
        M::reminder('create', (string) Str::uuid7(), $habit),
    ])->assertOk();
    app(PeriodCloser::class)->closeUser($user['id']);
    asUser($test, $user['token'], 'POST', '/exports', ['format' => 'json'])->assertStatus(202);
    Storage::disk('local')->put('avatars/'.$user['id'].'/'.Str::uuid7().'-lg.webp', 'RIFF');

    return $habit;
}

/** Every table that holds the user's rows, read from the schema so a new table cannot be missed. */
function ownedTables(): array
{
    $byUser = collect(DB::select("select table_name from information_schema.columns where table_schema = 'public' and column_name = 'user_id' and table_name <> 'account_deletions'"))->pluck('table_name');
    $byHabit = collect(DB::select("select distinct tc.table_name from information_schema.table_constraints tc
        join information_schema.constraint_column_usage ccu on ccu.constraint_name = tc.constraint_name
        where tc.constraint_type = 'FOREIGN KEY' and ccu.table_name = 'habits' and ccu.column_name = 'id'"))->pluck('table_name');

    return $byUser->merge($byHabit)->push('personal_access_tokens')->unique()->sort()->values()->all();
}

/** Row counts per owned table for one user (habit-owned tables through that user's habits). */
function ownedCounts(string $userId, array $habitIds): array
{
    $counts = [];
    foreach (ownedTables() as $table) {
        $q = DB::table($table);
        if ($table === 'personal_access_tokens') {
            $q->where('tokenable_id', $userId);
        } elseif (DB::getSchemaBuilder()->hasColumn($table, 'user_id')) {
            $q->where('user_id', $userId);
        } else {
            $q->whereIn('habit_id', $habitIds === [] ? ['00000000-0000-7000-8000-000000000000'] : $habitIds);
        }
        $counts[$table] = $q->count();
    }

    return $counts;
}

it('deletes on the right password: 202 in the fixture shape, every session revoked at once', function () {
    Queue::fake();
    $user = deletableUser($this);

    $response = asUser($this, $user['token'], 'DELETE', '/me', deleteMeFixture()['request']);

    $response->assertStatus(deleteMeFixture()['accepted']['status']);
    assertMatchesContract(deleteMeFixture()['accepted']['body'], $response->json());
    expect($response->json('data.receipt_expires_at'))->toBe('2026-07-02T17:22:00Z')
        ->and(DB::table('users')->where('id', $user['id'])->value('deleted_at'))->not->toBeNull()
        ->and(DB::table('personal_access_tokens')->where('tokenable_id', $user['id'])->count())->toBe(0);
    $row = DB::table('account_deletions')->first();
    expect($row->receipt_hash)->toBe(hash('sha256', (string) $response->json('data.receipt_token')))
        ->and($row->purge_after)->toBe($row->requested_at);

    foreach ([$user['token'], $user['other']] as $token) {
        asUser($this, $token, 'GET', '/me')->assertUnauthorized()->assertJsonPath('error.code', 'unauthenticated');
        app('auth')->forgetGuards();
        $this->sync($token)->assertUnauthorized();
    }
});

it('refuses a wrong or missing password with the fixture error and changes nothing', function () {
    $user = deletableUser($this);

    $wrong = asUser($this, $user['token'], 'DELETE', '/me', ['password' => 'not the password at all']);
    $wrong->assertStatus(deleteMeFixture()['wrong_password']['status']);
    assertMatchesContract(deleteMeFixture()['wrong_password']['body'], $wrong->json());

    asUser($this, $user['token'], 'DELETE', '/me', [])->assertStatus(422)->assertJsonPath('error.code', 'validation_failed')
        ->assertJsonStructure(['error' => ['fields' => ['password']]]);
    expect(DB::table('users')->where('id', $user['id'])->value('deleted_at'))->toBeNull()
        ->and(DB::table('account_deletions')->count())->toBe(0);
    asUser($this, $user['token'], 'GET', '/me')->assertOk();
});

it('throttles password attempts like login', function () {
    config(['api.rate_limits.auth_per_minute_per_email' => 3]);
    $user = deletableUser($this);
    foreach (range(1, 3) as $_) {
        asUser($this, $user['token'], 'DELETE', '/me', ['password' => 'not the password at all'])->assertStatus(422);
    }
    asUser($this, $user['token'], 'DELETE', '/me', deleteMeFixture()['request'])->assertStatus(429)->assertHeader('Retry-After');
    expect(DB::table('users')->where('id', $user['id'])->value('deleted_at'))->toBeNull();
});

it('lets the receipt read its own status in each state and nothing else', function () {
    Queue::fake();
    $user = deletableUser($this);
    $data = asUser($this, $user['token'], 'DELETE', '/me', deleteMeFixture()['request'])->json('data');
    $statuses = contractFixture('auth/account_deletion_status.json')['statuses'];

    assertMatchesContract($statuses['queued'], statusWith($this, $data['receipt_token'], $data['id'])->assertOk()->json('data'));
    DB::table('account_deletions')->update(['status' => 'purging']);
    assertMatchesContract($statuses['purging'], statusWith($this, $data['receipt_token'], $data['id'])->assertOk()->json('data'));
    app(AccountPurger::class)->purge($data['id']);
    $completed = statusWith($this, $data['receipt_token'], $data['id'])->assertOk()->json('data');
    assertMatchesContract($statuses['completed'], $completed);
    expect($completed['completed_at'])->toBe('2026-05-28T17:22:00Z');

    // Another deletion's id with this receipt, a wrong receipt, none, and a session token: 404.
    Queue::fake();
    $other = deletableUser($this, 'other@example.com');
    $otherData = asUser($this, $other['token'], 'DELETE', '/me', deleteMeFixture()['request'])->json('data');
    $live = deletableUser($this, 'live@example.com');
    foreach ([
        [$data['receipt_token'], $otherData['id']],
        [str_repeat('x', 48), $data['id']],
        [null, $data['id']],
        [$live['token'], $data['id']],
        [$data['receipt_token'], 'not-a-uuid'],
    ] as [$receipt, $id]) {
        $response = statusWith($this, $receipt, $id)->assertNotFound();
        assertMatchesContract(contractFixture('envelope/error_404_not_found.json')['body'], $response->json());
    }

    // The receipt is not a session anywhere else.
    asUser($this, $data['receipt_token'], 'GET', '/me')->assertUnauthorized();
    asUser($this, $data['receipt_token'], 'GET', '/exports')->assertUnauthorized();
    app('auth')->forgetGuards();
    $this->sync($data['receipt_token'])->assertUnauthorized();
});

it('refuses an expired receipt', function () {
    Queue::fake();
    $user = deletableUser($this);
    $data = asUser($this, $user['token'], 'DELETE', '/me', deleteMeFixture()['request'])->json('data');

    $this->freezeClock('2026-07-02T17:21:59Z');
    statusWith($this, $data['receipt_token'], $data['id'])->assertOk();
    $this->freezeClock('2026-07-02T17:22:00Z');
    statusWith($this, $data['receipt_token'], $data['id'])->assertNotFound();
});

it('answers login like a wrong password and refuses the email at register until the purge completes', function () {
    Queue::fake();
    $user = deletableUser($this);
    $data = asUser($this, $user['token'], 'DELETE', '/me', deleteMeFixture()['request'])->json('data');

    $login = fn () => asUser($this, null, 'POST', '/auth/login', ['email' => $user['email'], 'password' => $user['password'], 'device_name' => 'x']);
    $unknown = asUser($this, null, 'POST', '/auth/login', ['email' => 'nobody@example.com', 'password' => $user['password'], 'device_name' => 'x']);
    $deleted = $login();
    $deleted->assertStatus(422);
    expect($deleted->json('error.fields'))->toBe($unknown->json('error.fields'))
        ->and($deleted->json('error.message'))->toBe($unknown->json('error.message'));

    $register = fn () => asUser($this, null, 'POST', '/auth/register', ['name' => 'Maya', 'email' => $user['email'], 'password' => $user['password'],
        'timezone' => 'America/Los_Angeles', 'device_name' => 'x', 'terms_version' => '2026-10-24', 'privacy_version' => '2026-10-24']);
    $taken = deletableUser($this, 'taken@example.com');
    $existing = asUser($this, null, 'POST', '/auth/register', ['name' => 'T', 'email' => $taken['email'], 'password' => $user['password'],
        'timezone' => 'America/Los_Angeles', 'device_name' => 'x', 'terms_version' => '2026-10-24', 'privacy_version' => '2026-10-24']);
    $refused = $register()->assertStatus(422);
    expect($refused->json('error.fields'))->toBe($existing->json('error.fields'));

    app(AccountPurger::class)->purge($data['id']);
    $register()->assertCreated();
});

it('purges every owned row in every owned table and the objects, and no other user\'s', function () {
    $maya = deletableUser($this);
    $habit = populate($this, $maya);
    $sam = deletableUser($this, 'sam@example.com');
    $samHabit = populate($this, $sam);
    $samBefore = ownedCounts($sam['id'], [$samHabit]);
    $mayaBefore = ownedCounts($maya['id'], [$habit]);
    // The flows reached most tables; the coverage check below holds for the rest.
    expect(collect($mayaBefore)->filter()->count())->toBeGreaterThanOrEqual(12);

    Queue::fake();
    $data = asUser($this, $maya['token'], 'DELETE', '/me', deleteMeFixture()['request'])->json('data');
    app(AccountPurger::class)->purge($data['id']);

    expect(array_filter(ownedCounts($maya['id'], [$habit])))->toBe([])
        ->and(DB::table('users')->where('id', $maya['id'])->exists())->toBeFalse()
        ->and(Storage::disk('local')->allFiles('exports/'.$maya['id']))->toBe([])
        ->and(Storage::disk('local')->allFiles('avatars/'.$maya['id']))->toBe([])
        ->and(ownedCounts($sam['id'], [$samHabit]))->toBe($samBefore)
        ->and(Storage::disk('local')->allFiles('avatars/'.$sam['id']))->not->toBe([])
        ->and(DB::table('account_deletions')->where('id', $data['id'])->first())
        ->user_id->toBeNull()->status->toBe('completed');

    // Safe to run twice.
    app(AccountPurger::class)->purge($data['id']);
    expect(ownedCounts($sam['id'], [$samHabit]))->toBe($samBefore);
});

it('names every owned table in the purge order', function () {
    expect(collect(AccountPurger::ORDER)->pluck(0)->sort()->values()->all())->toBe(ownedTables());
});

it('never purges an account that was not deleted', function () {
    $maya = deletableUser($this);
    $id = (string) Str::uuid7();
    DB::table('account_deletions')->insert(['id' => $id, 'user_id' => $maya['id'], 'status' => 'queued',
        'requested_at' => '2026-05-28 17:22:00+00', 'purge_after' => '2026-05-28 17:22:00+00',
        'receipt_hash' => hash('sha256', 'x'), 'receipt_expires_at' => '2026-07-02 17:22:00+00',
        'created_at' => '2026-05-28 17:22:00+00', 'updated_at' => '2026-05-28 17:22:00+00']);

    expect(fn () => app(AccountPurger::class)->purge($id))->toThrow(LogicException::class);
    expect(DB::table('users')->where('id', $maya['id'])->exists())->toBeTrue();
});

it('runs the purge from the queue at once, and the scheduled command picks up any left behind', function () {
    $maya = deletableUser($this);
    $data = asUser($this, $maya['token'], 'DELETE', '/me', deleteMeFixture()['request'])->json('data');
    expect(DB::table('account_deletions')->value('status'))->toBe('completed');

    Queue::fake();
    $sam = deletableUser($this, 'sam@example.com');
    asUser($this, $sam['token'], 'DELETE', '/me', deleteMeFixture()['request'])->assertStatus(202);
    Queue::fake();
    Artisan::call('accounts:purge', ['--sync' => true]);
    expect(DB::table('users')->where('id', $sam['id'])->exists())->toBeFalse()
        ->and(DB::table('account_deletions')->where('status', '<>', 'completed')->count())->toBe(0)
        ->and($data['status'])->toBe('queued');
});

it('never logs more than ids about the deleted person', function () {
    $log = storage_path('logs/deletion-test.log');
    @unlink($log);
    config(['logging.channels.single.path' => $log, 'logging.default' => 'single']);
    app('log')->forgetChannel('single');
    $maya = deletableUser($this);
    asUser($this, $maya['token'], 'DELETE', '/me', deleteMeFixture()['request'])->assertStatus(202);

    $text = is_file($log) ? (string) file_get_contents($log) : '';
    expect($text)->not->toContain($maya['email'])->not->toContain('Maya')->not->toContain($maya['password']);
    @unlink($log);
});

it('keeps the avatar and export stores out of other users\' folders', function () {
    $maya = deletableUser($this);
    $sam = deletableUser($this, 'sam@example.com');
    Storage::disk('local')->put('avatars/'.$sam['id'].'/x-lg.webp', 'RIFF');
    Storage::disk('local')->put('exports/'.$sam['id'].'/x.zip', 'PK');

    app(AvatarStore::class)->deleteAllFor($maya['id']);
    app(ExportStore::class)->deleteAllFor($maya['id']);

    expect(Storage::disk('local')->allFiles('avatars/'.$sam['id']))->toHaveCount(1)
        ->and(Storage::disk('local')->allFiles('exports/'.$sam['id']))->toHaveCount(1);
});
