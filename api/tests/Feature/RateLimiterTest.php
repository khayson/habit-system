<?php

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\RateLimiter;

/**
 * @return list<Limit>
 */
function limitsFor(string $name, Request $request): array
{
    $callback = RateLimiter::limiter($name);
    expect($callback)->not->toBeNull("limiter {$name} is not defined");

    return array_values(Arr::wrap($callback($request)));
}

it('defines every limiter the API will use', function (string $name) {
    expect(limitsFor($name, Request::create('/', 'POST', ['email' => 'maya@example.com'])))->not->toBeEmpty();
})->with(['api', 'auth', 'password-reset', 'sync', 'avatar-upload']);

it('limits avatar uploads to 10 per hour (A20)', function () {
    [$limit] = limitsFor('avatar-upload', Request::create('/'));

    expect($limit->maxAttempts)->toBe(10)->and($limit->decaySeconds)->toBe(3600);
});

it('keys auth attempts by normalized email and IP', function () {
    $keys = fn (string $email) => array_map(
        fn (Limit $l) => $l->key,
        limitsFor('auth', Request::create('/', 'POST', ['email' => $email], server: ['REMOTE_ADDR' => '10.0.0.1'])),
    );

    expect($keys('Maya@Example.com '))->toBe($keys('maya@example.com'));
});

it('applies the api limiter to the api route group', function () {
    $this->getJson('/api/v1/health')
        ->assertOk()
        ->assertHeader('X-RateLimit-Limit', '120');
});
