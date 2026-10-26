<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A55: a read-only status in numbers only, for the operator. GET /api/v1/internal/status with
 * X-Ops-Secret (404 otherwise, like the tick), and `php artisan ops:status`. No id, name, email,
 * habit name, note or token ever appears in it.
 */

const OPS_SECRET_FOR_TEST = 'ops-secret-for-tests-only-0123456789abcdef';

beforeEach(function () {
    config(['api.ops_secret' => OPS_SECRET_FOR_TEST, 'api.tick_secret' => 'tick-secret-for-ops-tests-0123456789', 'api.tick_memory_mb' => 4096]);
    $this->freezeClock('2026-05-28T17:22:00Z');
});

function opsStatus(object $test, ?string $secret = OPS_SECRET_FOR_TEST)
{
    return $test->getJson('/api/v1/internal/status', $secret === null ? [] : ['X-Ops-Secret' => $secret]);
}

it('is 404 without the secret, with a wrong one, with the tick secret, and when none is configured', function () {
    foreach ([null, 'wrong', 'tick-secret-for-ops-tests-0123456789'] as $secret) {
        opsStatus($this, $secret)->assertNotFound()->assertJsonPath('error.code', 'not_found');
    }
    config(['api.ops_secret' => '']);
    opsStatus($this, '')->assertNotFound();
    opsStatus($this)->assertNotFound();
});

it('reports accounts, the last 24 hours of check-ins, the queue, the database and the app version, in numbers only', function () {
    $maya = $this->registerUser('Maya');
    $sam = $this->registerUser('Sam');
    $habit = (string) Str::uuid7();
    $this->sync($maya['token'], [M::habitCreate($habit, overrides: ['name' => 'Secret diary habit'])])->assertOk();
    expect($this->sync($maya['token'], [M::setValue($habit, 1, 0, '2026-05-28T17:00:00Z')])->json('data.acks.0.status'))->toBe('accepted');
    DB::table('account_deletions')->insert([
        'id' => (string) Str::uuid7(), 'user_id' => $sam['id'], 'status' => 'queued',
        'receipt_hash' => str_repeat('a', 64), 'requested_at' => '2026-05-28 17:00:00+00', 'purge_after' => '2026-05-28 18:00:00+00', 'receipt_expires_at' => '2026-06-04 17:00:00+00', 'created_at' => '2026-05-28 17:00:00+00', 'updated_at' => '2026-05-28 17:00:00+00',
    ]);
    $created = (int) strtotime('2026-05-28T17:12:00Z');
    DB::table('jobs')->insert(['queue' => 'default', 'payload' => '{}', 'attempts' => 0, 'available_at' => $created, 'created_at' => $created]);
    DB::table('failed_jobs')->insert(['uuid' => (string) Str::uuid(), 'connection' => 'database', 'queue' => 'default', 'payload' => '{}', 'exception' => 'x']);

    $response = opsStatus($this)->assertOk();
    $data = $response->json('data');
    expect(array_keys($data))->toBe(['accounts', 'check_ins_last_24h', 'queue', 'last_tick_at', 'mail_failures', 'database', 'min_app_version'])
        ->and($data['accounts'])->toBe(['live' => 2, 'deletions_pending' => 1])
        ->and($data['check_ins_last_24h'])->toBe(1)
        ->and($data['queue'])->toBe(['waiting' => 1, 'oldest_waiting_seconds' => 600, 'failed' => 1])
        ->and($data['last_tick_at'])->toBeNull()
        ->and($data['mail_failures'])->toBe(['last_7_days' => 0, 'last_at' => null])
        ->and($data['database']['size_bytes'])->toBeInt()->toBeGreaterThan(0)
        ->and($data['database']['limit_bytes'])->toBe(536870912)
        ->and($data['database']['used_percent'])->toBeNumeric()
        ->and($data['min_app_version'])->toBe(1);

    $body = (string) $response->getContent();
    foreach ([$maya['id'], $sam['id'], $habit, 'Maya', 'Sam', 'Secret diary habit', '@'] as $personal) {
        expect($body)->not->toContain($personal);
    }
});

it('shows when the last tick ran', function () {
    $this->postJson('/api/v1/internal/tick', [], ['X-Tick-Secret' => 'tick-secret-for-ops-tests-0123456789'])->assertNoContent();
    opsStatus($this)->assertJsonPath('data.last_tick_at', '2026-05-28T17:22:00Z');
});

it('counts reset-email failures of the last 7 days and when the last one happened', function () {
    $this->registerUser('Maya', email: 'maya.ops@example.test');
    // A mail server that refuses the connection: the send fails after the 202.
    config(['mail.default' => 'smtp', 'mail.mailers.smtp.host' => '127.0.0.1', 'mail.mailers.smtp.port' => 1, 'mail.mailers.smtp.timeout' => 2]);
    $this->postJson('/api/v1/auth/forgot-password', ['email' => 'maya.ops@example.test'])->assertStatus(202);

    opsStatus($this)->assertJsonPath('data.mail_failures', ['last_7_days' => 1, 'last_at' => '2026-05-28T17:22:00Z']);

    $this->freezeClock('2026-06-06T09:00:00Z');
    opsStatus($this)->assertJsonPath('data.mail_failures.last_7_days', 0);
});

it('prints the same numbers from the command', function () {
    $this->registerUser('Maya');
    expect(Artisan::call('ops:status', ['--json' => true]))->toBe(0);
    $fromCommand = json_decode(Artisan::output(), true);
    expect($fromCommand)->toBe(opsStatus($this)->json('data'));

    expect(Artisan::call('ops:status'))->toBe(0)
        ->and(Artisan::output())->toContain('Live accounts')->toContain('1');
});
