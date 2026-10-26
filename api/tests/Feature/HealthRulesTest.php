<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Testing\TestResponse;

/*
 * A54: outside local and testing, /health answers 503 unavailable when the database does not
 * answer or mail cannot reach anyone (the 6.4 review's answer), as it already does for a test
 * export key. The body says only unavailable; the reason goes to the log.
 */

/** A production-like configuration that is healthy until a test breaks one part. */
function productionHealth(array $config = []): void
{
    app()['env'] = 'production';
    config([
        'api.export_signing_keys' => 'prod-1:'.str_repeat('k', 40),
        'api.export_signing_kid' => 'prod-1',
        'mail.default' => 'smtp',
        'mail.from.address' => 'hello@habits.khaystudios.test',
        ...$config,
    ]);
}

function expectUnavailable(TestResponse $response): void
{
    $fixture = contractFixture('envelope/error_503_unavailable.json');
    $response->assertStatus($fixture['status']);
    assertMatchesContract($fixture['body'], $response->json());
}

it('is healthy with a real mailer, a real sender and a database that answers', function () {
    productionHealth();
    $this->getJson('/api/v1/health')->assertOk()->assertJsonPath('data.status', 'ok');
});

it('is unavailable when mail only goes to the log or an array, and logs why', function (string $mailer) {
    Log::spy();
    productionHealth(['mail.default' => $mailer]);
    expectUnavailable($this->getJson('/api/v1/health'));
    Log::shouldHaveReceived('critical')->once()->with('mail not deliverable', ['reason' => 'mailer_'.$mailer]);
})->with(['log', 'array']);

it('is unavailable when the sender is empty or a placeholder address', function (?string $from) {
    Log::spy();
    productionHealth(['mail.from.address' => $from]);
    expectUnavailable($this->getJson('/api/v1/health'));
    Log::shouldHaveReceived('critical')->once()->with('mail not deliverable', ['reason' => 'sender']);
})->with([null, '', 'hello@example.com', 'noreply@mail.example.com', 'HELLO@EXAMPLE.COM']);

it('is unavailable when the database does not answer, and says nothing more', function () {
    Log::spy();
    productionHealth();
    config([
        'database.connections.unreachable' => [
            ...config('database.connections.pgsql'),
            'host' => '127.0.0.1',
            'port' => 1,
            'url' => null,
        ],
        'database.default' => 'unreachable',
    ]);
    DB::purge('unreachable');
    $response = $this->getJson('/api/v1/health');
    expectUnavailable($response);
    expect($response->getContent())->not->toContain('127.0.0.1')->not->toContain('SQLSTATE');
    Log::shouldHaveReceived('critical')->once()->with('database not answering', []);
});

it('keeps local and testing healthy whatever the mail settings', function () {
    app()['env'] = 'local';
    config(['mail.default' => 'log', 'mail.from.address' => 'hello@example.com']);
    $this->getJson('/api/v1/health')->assertOk();
});
