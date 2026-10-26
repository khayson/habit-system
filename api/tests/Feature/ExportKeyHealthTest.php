<?php

use Illuminate\Support\Facades\Log;
use Illuminate\Testing\TestResponse;

/*
 * 6.1 review L3: outside local and testing, /health reports unhealthy (503 unavailable) when the
 * current export signing key is the published test key or shorter than 32 bytes, so a deploy's
 * health check stops it; a missing key is logged clearly. The reason is logged, never answered.
 */

const PUBLISHED_TEST_SECRET = 'test-export-signing-secret-not-for-production';

function healthIn(object $test, string $env, string $keys, string $kid = 'prod-1'): TestResponse
{
    app()['env'] = $env;
    // A54: mail is healthy here, so only the export key decides.
    config(['api.export_signing_keys' => $keys, 'api.export_signing_kid' => $kid, 'mail.default' => 'smtp', 'mail.from.address' => 'hello@habits.khaystudios.test']);

    return $test->getJson('/api/v1/health');
}

function assertUnavailable(TestResponse $response): void
{
    $fixture = contractFixture('envelope/error_503_unavailable.json');
    $response->assertStatus($fixture['status']);
    assertMatchesContract($fixture['body'], $response->json());
}

it('is unhealthy in production with the published test secret, and logs why', function () {
    Log::spy();
    assertUnavailable(healthIn($this, 'production', 'prod-1:'.PUBLISHED_TEST_SECRET));
    Log::shouldHaveReceived('critical')->once()->with('export signing key unusable', ['kid' => 'prod-1', 'reason' => 'test_key']);
});

it('is unhealthy with a secret shorter than 32 bytes and healthy at 32', function () {
    Log::spy();
    assertUnavailable(healthIn($this, 'production', 'prod-1:'.str_repeat('k', 31)));
    Log::shouldHaveReceived('critical')->once()->with('export signing key unusable', ['kid' => 'prod-1', 'reason' => 'too_short']);

    healthIn($this, 'production', 'prod-1:'.str_repeat('k', 32))->assertOk()->assertJsonPath('data.status', 'ok');
});

it('judges the current kid only: an old test key kept for verification is fine', function () {
    healthIn($this, 'staging', 'test-2026:'.PUBLISHED_TEST_SECRET.',prod-1:'.str_repeat('k', 40))->assertOk();
    assertUnavailable(healthIn($this, 'staging', 'test-2026:'.PUBLISHED_TEST_SECRET.',prod-1:'.str_repeat('k', 40), 'test-2026'));
});

it('logs clearly when no key is set, and stays healthy', function () {
    Log::spy();
    healthIn($this, 'production', '', '')->assertOk();
    Log::shouldHaveReceived('warning')->once()->with('export signing key not set: exports will fail', ['kid' => '']);
});

it('accepts the test key in local and testing', function () {
    healthIn($this, 'local', 'test-2026:'.PUBLISHED_TEST_SECRET, 'test-2026')->assertOk();
    healthIn($this, 'testing', 'test-2026:'.PUBLISHED_TEST_SECRET, 'test-2026')->assertOk();
});
