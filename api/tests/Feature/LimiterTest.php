<?php

use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/*
 * Phase 0 carry-over: authenticated limits are keyed by user, so two people behind one carrier
 * IP never share a bucket. This only works if the throttle runs after auth:sanctum.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->alice = $this->registerUser('Alice');
    $this->bob = $this->registerUser('Bob');
});

it('gives two users behind one IP independent api buckets', function () {
    config(['api.rate_limits.api_per_minute' => 2]);
    $me = function (string $token) {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token)->withServerVariables(['REMOTE_ADDR' => '203.0.113.7'])->getJson('/api/v1/me');
    };

    $me($this->alice['token'])->assertOk();
    $me($this->alice['token'])->assertOk();
    $me($this->alice['token'])->assertStatus(429)->assertHeader('Retry-After');
    $me($this->bob['token'])->assertOk();
});

it('gives two users behind one IP independent sync buckets', function () {
    config(['api.rate_limits.sync_per_minute' => 1]);
    $sync = fn (string $token) => $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.7'])->sync($token);

    $sync($this->alice['token'])->assertOk();
    $sync($this->alice['token'])->assertStatus(429)->assertJsonPath('error.code', 'rate_limited');
    $sync($this->bob['token'])->assertOk();
});

it('throttles sign-in attempts by IP and email before any account exists', function () {
    config(['api.rate_limits.auth_per_minute_per_email' => 2]);
    $login = fn () => $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.7'])
        ->postJson('/api/v1/auth/login', ['email' => 'nobody@example.com', 'password' => 'x', 'device_name' => 'x']);

    $login()->assertStatus(422);
    $login()->assertStatus(422);
    $login()->assertStatus(429);
});
