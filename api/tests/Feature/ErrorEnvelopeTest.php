<?php

use App\Domain\Calendar\CalendarEntry;
use App\Domain\Calendar\DayResolutionException;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\UnknownHabitType;
use App\Domain\Habit\UnsupportedOperation;
use App\Exceptions\ApiException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\Exceptions\PostTooLargeException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;

/*
 * Each error shape is produced through the real HTTP kernel and compared with its golden
 * fixture in contract-fixtures/envelope/. The Dart suite parses the same files.
 */

beforeEach(function () {
    Route::prefix('api/v1/__test')->middleware('api')->group(function () {
        Route::get('/protected', fn () => 'never')->middleware('auth:sanctum');
        Route::get('/forbidden', fn () => throw new AuthorizationException('policy detail must not leak'));
        Route::get('/missing-model', fn () => throw (new ModelNotFoundException)->setModel('App\\Models\\Habit', ['abc']));
        Route::get('/version-conflict', fn () => throw ApiException::versionConflict(
            '55555555-5555-4555-8555-555555555555', 8, 9, ['value' => '1750.000'],
        ));
        Route::get('/idempotency-mismatch', fn () => throw ApiException::idempotencyMismatch());
        Route::get('/resource-deleted', fn () => throw ApiException::resourceDeleted('habit_log', '55555555-5555-4555-8555-555555555555', 10));
        Route::get('/cursor-expired', fn () => throw ApiException::cursorExpired());
        Route::get('/bad-request', fn () => abort(400, 'parser detail must not leak'));
        Route::post('/media-type', fn () => abort(415));
        Route::get('/unavailable', fn () => abort(503));
        Route::get('/teapot', fn () => abort(418));
        Route::get('/domain/{reason}', fn (string $reason) => throw new DayResolutionException(
            $reason,
            $reason === 'timezone_context_mismatch' ? new CalendarEntry(new DateTimeImmutable('2026-01-01T00:00:00Z'), 'America/Los_Angeles') : null,
        ));
        Route::get('/domain-type', fn () => throw new UnknownHabitType('checklist'));
        Route::get('/domain-operation', fn () => throw new UnsupportedOperation('binary', 'log.increment'));
        Route::get('/domain-value', fn () => throw new InvalidHabitValue('internal detail 250.0005'));
        Route::post('/too-large', fn () => throw new PostTooLargeException);
        Route::post('/validate', function (Request $request) {
            $request->validate(
                ['target_value' => ['required', 'numeric', 'gt:0']],
                ['target_value.gt' => 'Duration must be greater than zero.'],
            );

            return 'ok';
        });
        Route::post('/login-like', fn () => 'ok')->middleware('throttle:auth');
        Route::get('/boom', fn () => throw new RuntimeException('SQLSTATE secret-table password=hunter2'));
    });
});

function expectFixture(string $name, TestResponse $response): void
{
    $fixture = contractFixture("envelope/{$name}.json");

    $response->assertStatus($fixture['status']);
    assertMatchesContract($fixture['body'], $response->json());
    foreach ($fixture['headers'] ?? [] as $header => $expected) {
        assertMatchesContract($expected, $response->headers->get($header), "header {$header}");
    }
    expect($response->headers->get('X-Request-Id'))->toBe($response->json('meta.request_id'));
}

it('401 for a protected route without a token', function () {
    expectFixture('error_401_unauthenticated', $this->getJson('/api/v1/__test/protected'));
});

it('401 without redirecting when the client does not ask for JSON', function () {
    expectFixture('error_401_unauthenticated', $this->get('/api/v1/__test/protected'));
});

it('403 for a policy denial without leaking the reason', function () {
    expectFixture('error_403_forbidden', $this->getJson('/api/v1/__test/forbidden'));
});

it('404 for an unknown route', function () {
    expectFixture('error_404_not_found', $this->getJson('/api/v1/does-not-exist'));
});

it('404 for a missing or foreign model with no model name or id in the body', function () {
    $response = $this->getJson('/api/v1/__test/missing-model');

    expectFixture('error_404_not_found', $response);
    expect($response->getContent())->not->toContain('Habit')->not->toContain('abc');
});

it('409 version_conflict carries the canonical current resource', function () {
    expectFixture('error_409_version_conflict', $this->getJson('/api/v1/__test/version-conflict'));
});

it('409 idempotency_mismatch', function () {
    expectFixture('error_409_idempotency_mismatch', $this->getJson('/api/v1/__test/idempotency-mismatch'));
});

it('409 resource_deleted carries the tombstone version', function () {
    expectFixture('error_409_resource_deleted', $this->getJson('/api/v1/__test/resource-deleted'));
});

it('410 cursor_expired', function () {
    expectFixture('error_410_cursor_expired', $this->getJson('/api/v1/__test/cursor-expired'));
});

it('413 when a handler rejects an oversized payload', function () {
    expectFixture('error_413_payload_too_large', $this->postJson('/api/v1/__test/too-large'));
});

it('413 when the body exceeds post_max_size (framework middleware)', function () {
    $response = $this->call('POST', '/api/v1/health', server: [
        'CONTENT_LENGTH' => (string) (PHP_INT_MAX >> 1),
        'HTTP_ACCEPT' => 'application/json',
    ]);

    expectFixture('error_413_payload_too_large', $response);
});

it('422 validation_failed with per-field messages', function () {
    expectFixture('error_422_validation_failed', $this->postJson('/api/v1/__test/validate', ['target_value' => 0]));
});

it('429 with Retry-After once the auth limiter is exhausted', function () {
    foreach (range(1, 5) as $attempt) {
        $this->postJson('/api/v1/__test/login-like', ['email' => 'Maya@example.com'])->assertOk();
    }

    // Same mailbox after normalisation (case and whitespace) shares the bucket.
    $response = $this->postJson('/api/v1/__test/login-like', ['email' => '  maya@EXAMPLE.com ']);

    expectFixture('error_429_rate_limited', $response);
});

it('405 for a wrong method keeps the envelope and the Allow header', function () {
    expectFixture('error_405_method_not_allowed', $this->deleteJson('/api/v1/health'));
});

it('400 bad_request without leaking the reason', function () {
    $response = $this->getJson('/api/v1/__test/bad-request');

    expectFixture('error_400_bad_request', $response);
    expect($response->getContent())->not->toContain('parser detail');
});

it('415 unsupported_media_type', function () {
    expectFixture('error_415_unsupported_media_type', $this->postJson('/api/v1/__test/media-type'));
});

it('503 unavailable', function () {
    expectFixture('error_503_unavailable', $this->getJson('/api/v1/__test/unavailable'));
});

it('falls back to http_error for any other 4xx', function () {
    expectFixture('error_4xx_http_error', $this->getJson('/api/v1/__test/teapot'));
});

it('500 never leaks exception text, even with debug on', function () {
    config(['app.debug' => true]);

    $response = $this->getJson('/api/v1/__test/boom');

    expectFixture('error_500_server_error', $response);
    expect($response->getContent())
        ->not->toContain('SQLSTATE')
        ->not->toContain('hunter2')
        ->not->toContain('trace');
});

it('maps day-resolution errors through the domain mapper', function (string $reason) {
    expectFixture("error_422_{$reason}", $this->getJson("/api/v1/__test/domain/{$reason}"));
})->with(['future_event', 'event_too_old', 'timezone_context_mismatch', 'backdate_future', 'backdate_too_old']);

it('maps habit-type errors through the domain mapper without leaking detail', function (string $route, string $code) {
    $response = $this->getJson("/api/v1/__test/{$route}");

    expectFixture("error_422_{$code}", $response);
    expect($response->getContent())->not->toContain('internal detail')->not->toContain('checklist');
})->with([
    ['domain-type', 'unsupported_type'],
    ['domain-operation', 'unsupported_operation'],
    ['domain-value', 'invalid_value'],
]);

it('treats an unmapped domain reason as a server error, not a silent 422', function () {
    expectFixture('error_500_server_error', $this->getJson('/api/v1/__test/domain/not_a_reason'));
});
