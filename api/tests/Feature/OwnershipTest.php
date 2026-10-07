<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Route as RoutingRoute;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Invariant 2: every query is owner-scoped; a foreign id is indistinguishable from a missing one.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->alice = $this->registerUser('Alice');
    $this->bob = $this->registerUser('Bob');
    $this->aliceHabit = (string) Str::uuid7();
    $this->sync($this->alice['token'], [M::habitCreate($this->aliceHabit)]);
    $this->aliceLog = $this->sync($this->alice['token'], [M::setValue($this->aliceHabit, 1, 0)])->json('data.acks.0.entity_id');
});

/** Ack minus ids that differ between requests by construction. */
function comparableAck(array $ack): array
{
    unset($ack['mutation_id'], $ack['entity_id']);

    return $ack;
}

it('treats a foreign habit in a log mutation exactly like a missing one', function () {
    $foreign = $this->sync($this->bob['token'], [M::setValue($this->aliceHabit, 0, 1)])->json('data.acks.0');
    $missing = $this->sync($this->bob['token'], [M::setValue((string) Str::uuid7(), 0, 1)])->json('data.acks.0');

    expect($foreign['status'])->toBe('dependency_pending')
        ->and(comparableAck($foreign))->toBe(comparableAck($missing));
    expect(DB::table('habit_logs')->where('id', $this->aliceLog)->value('value'))->toBe('1.000');
});

it('treats a foreign log in a delete exactly like a missing one', function () {
    $foreign = $this->sync($this->bob['token'], [M::delete($this->aliceLog, 1, $this->aliceHabit)])->json('data.acks.0');
    $missing = $this->sync($this->bob['token'], [M::delete((string) Str::uuid7(), 1, $this->aliceHabit)])->json('data.acks.0');

    expect($foreign['error']['code'])->toBe('not_found')
        ->and(comparableAck($foreign))->toBe(comparableAck($missing));
    expect(DB::table('habit_logs')->where('id', $this->aliceLog)->value('deleted_at'))->toBeNull();
});

it('refuses habit.create on another owner\'s id without revealing it', function () {
    $ack = $this->sync($this->bob['token'], [M::habitCreate($this->aliceHabit)])->json('data.acks.0');

    expect($ack['status'])->toBe('rejected')
        ->and($ack['error'])->toBe(['code' => 'not_found', 'message' => 'Not found.']);
    expect(DB::table('habits')->where('id', $this->aliceHabit)->value('user_id'))->toBe($this->alice['id']);
});

it('never shows one owner\'s changes, habits or logs to another', function () {
    $pull = $this->sync($this->bob['token'])->json('data');
    $this->app['auth']->forgetGuards();
    $bootstrap = $this->withToken($this->bob['token'])->getJson('/api/v1/sync/bootstrap?limit=500');
    $bootstrapLogs = $this->withToken($this->bob['token'])->getJson('/api/v1/sync/bootstrap?cursor='.urlencode((string) $bootstrap->json('data.next_cursor')));

    expect(array_column($pull['changes'], 'entity'))->toBe(['user'])
        ->and($pull['changes'][0]['id'])->toBe($this->bob['id'])
        ->and($bootstrap->json('data.habits'))->toBe([])
        ->and($bootstrapLogs->json('data.logs'))->toBe([])
        ->and($bootstrap->json('data.user.id'))->toBe($this->bob['id']);
});

it('keeps duplicate detection per owner: the same mutation id from two owners is two mutations', function () {
    $mutationId = (string) Str::uuid7();
    $bobHabit = (string) Str::uuid7();

    $this->sync($this->bob['token'], [M::habitCreate($bobHabit, mutationId: $mutationId)])->assertJsonPath('data.acks.0.duplicate', false);
    $this->sync($this->alice['token'], [M::habitCreate((string) Str::uuid7(), mutationId: $mutationId)])->assertJsonPath('data.acks.0.duplicate', false);

    expect(DB::table('mutation_receipts')->where('mutation_id', $mutationId)->count())->toBe(2);
});

it('requires authentication on every route except health, register and login', function () {
    $public = ['api/v1/health', 'api/v1/auth/register', 'api/v1/auth/login'];

    $routes = collect(Route::getRoutes()->getRoutes())->filter(fn (RoutingRoute $r) => str_starts_with($r->uri(), 'api/v1/') && ! str_starts_with($r->uri(), 'api/v1/__test'));
    expect($routes)->not->toBeEmpty();

    foreach ($routes as $route) {
        if (in_array($route->uri(), $public, true)) {
            continue;
        }
        expect(in_array('auth:sanctum', $route->gatherMiddleware(), true))->toBeTrue("{$route->uri()} is not authenticated");
        $method = $route->methods()[0];
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $this->json($method, '/'.$route->uri())->assertUnauthorized()->assertJsonPath('error.code', 'unauthenticated');
    }
});
