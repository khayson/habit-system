<?php

namespace Tests;

use App\Domain\Clock;
use App\Infrastructure\FrozenClock;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;

abstract class TestCase extends BaseTestCase
{
    /** Freezes the domain Clock and Laravel's clock together (token expiry uses the latter). */
    protected function freezeClock(string $instant): FrozenClock
    {
        // Move an already frozen clock rather than replacing it: route controllers (and the
        // services they hold) are cached across requests within one test.
        $current = $this->app->make(Clock::class);
        $clock = $current instanceof FrozenClock ? $current : new FrozenClock($instant);
        $clock->set($instant);
        $this->app->instance(Clock::class, $clock);
        $this->travelTo(CarbonImmutable::parse($instant));

        return $clock;
    }

    /**
     * Registers an account through the API.
     *
     * @return array{id: string, token: string, email: string}
     */
    public function registerUser(string $name = 'Maya Chen', ?string $email = null, string $timezone = 'America/Los_Angeles'): array
    {
        $email ??= Str::lower(Str::random(10)).'@example.com';
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => $name,
            'email' => $email,
            'password' => 'correct horse battery staple',
            'timezone' => $timezone,
            'device_name' => "{$name}'s phone",
            'device_id' => (string) Str::uuid7(),
            // A33: the accepted docs/legal versions.
            'terms_version' => '2026-10-10',
            'privacy_version' => '2026-10-10',
        ])->assertCreated();

        return ['id' => (string) $response->json('data.user.id'), 'token' => (string) $response->json('data.token'), 'email' => $email];
    }

    /**
     * @param  list<array<string, mixed>>  $mutations
     * @param  array<string, string>  $headers
     */
    public function sync(string $token, array $mutations = [], ?string $cursor = null, ?int $pullLimit = null, array $headers = [], ?string $deviceId = null): TestResponse
    {
        // The test client keeps the last authenticated user between requests; each call must
        // authenticate from its own token, like separate HTTP requests do.
        $this->app['auth']->forgetGuards();

        return $this->withToken($token)->postJson('/api/v1/sync', array_filter([
            'device_id' => $deviceId ?? '01970000-0000-7000-8000-00000000d001',
            'cursor' => $cursor,
            'pull_limit' => $pullLimit,
            'mutations' => $mutations,
        ], fn ($v) => $v !== null), $headers);
    }

    public function bootstrapPage(string $token, ?string $cursor, int $limit): TestResponse
    {
        $this->app['auth']->forgetGuards();

        return $this->withToken($token)
            ->getJson('/api/v1/sync/bootstrap?limit='.$limit.($cursor === null ? '' : '&cursor='.urlencode($cursor)))
            ->assertOk();
    }
}
