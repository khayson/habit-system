<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

/*
 * A54: the service is reachable only through Render's proxy, so its X-Forwarded-* headers are
 * trusted: request()->ip() is the client's address (the per-IP throttles depend on it) and the
 * scheme is https. Responses carry HSTS outside local and testing.
 */

beforeEach(function () {
    Route::get('/api/v1/_probe', fn (Request $request) => [
        'ip' => $request->ip(),
        'secure' => $request->isSecure(),
        'url' => url('/api/v1/health'),
    ]);
});

it('takes the client address and scheme from the proxy headers', function () {
    config(['api.trusted_proxies' => '*', 'app.url' => 'https://habit.onrender.test']);
    $response = $this->withServerVariables(['REMOTE_ADDR' => '10.10.0.7'])
        ->getJson('/api/v1/_probe', ['X-Forwarded-For' => '203.0.113.9', 'X-Forwarded-Proto' => 'https']);
    $response->assertOk()
        ->assertJsonPath('ip', '203.0.113.9')
        ->assertJsonPath('secure', true);
    expect($response->json('url'))->toStartWith('https://');
});

it('ignores the headers when no proxy is trusted', function () {
    config(['api.trusted_proxies' => '']);
    $this->withServerVariables(['REMOTE_ADDR' => '10.10.0.7'])
        ->getJson('/api/v1/_probe', ['X-Forwarded-For' => '203.0.113.9'])
        ->assertJsonPath('ip', '10.10.0.7');
});

it('sends Strict-Transport-Security in production, not in testing', function () {
    $this->getJson('/api/v1/health')->assertHeaderMissing('Strict-Transport-Security');
    app()['env'] = 'production';
    config(['mail.default' => 'smtp', 'mail.from.address' => 'hello@habits.khaystudios.test', 'api.export_signing_keys' => 'k:'.str_repeat('x', 40), 'api.export_signing_kid' => 'k']);
    $this->getJson('/api/v1/health')->assertHeader('Strict-Transport-Security', 'max-age=31536000');
});
