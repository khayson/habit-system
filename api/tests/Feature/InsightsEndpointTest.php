<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A47: GET /insights through HTTP, one test per case of contract-fixtures/insights. Each case's
 * seed is built through the real /sync path (habits, backdated logs, archive, auto-freeze), so
 * the stored period evaluations and freeze usages are the ones the closer writes.
 */

/** @return list<array<string, mixed>> */
function insightsCases(): array
{
    $cases = [];
    foreach (glob(contractFixturePath('insights/*.json')) ?: [] as $path) {
        $fixture = json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
        if (in_array('php', $fixture['suites'], true)) {
            array_push($cases, ...$fixture['cases']);
        }
    }

    return $cases;
}

/**
 * Builds a case's seed for a new user and returns the user.
 *
 * @param  array<string, mixed>  $case
 * @return array{id: string, token: string, email: string}
 */
function seedInsights(object $test, array $case): array
{
    $seed = $case['seed'];
    $test->freezeClock($seed['auto_freeze_from'] ?? $case['now']);
    $user = $test->registerUser('Maya', timezone: $case['timezone']);
    if (isset($seed['auto_freeze_from'])) {
        $version = (int) DB::table('users')->where('id', $user['id'])->value('version');
        $test->sync($user['token'], [M::setAutoFreeze($user['id'], true, $version, $seed['auto_freeze_from'])])
            ->assertJsonPath('data.acks.0.status', 'accepted');
    }
    $test->freezeClock($case['now']);

    $habits = [];
    if (($seed['from'] ?? null) !== null) {
        $domain = contractFixture($seed['from'])['seed'];
        foreach ($domain['habits'] as $h) {
            $d = $h['definitions'][0];
            $habits[] = [
                'id' => $h['id'], 'name' => $h['name'], 'category' => $h['category'], 'type' => $d['type'],
                'target' => $d['target'], 'unit' => $d['unit'], 'frequency_type' => $d['frequency_type'],
                'frequency_config' => $d['frequency_config'], 'start_local_date' => $h['active_ranges'][0]['starts_on'],
                'logs' => $h['logs'],
            ];
        }
    }
    array_push($habits, ...($seed['extra_habits'] ?? []));

    foreach ($habits as $h) {
        $test->sync($user['token'], [M::habitCreate($h['id'], $h['type'], $h['target'], [
            'name' => $h['name'], 'unit' => $h['unit'] ?? null, 'category' => $h['category'],
            'frequency_type' => $h['frequency_type'], 'frequency_config' => $h['frequency_config'],
            'start_local_date' => $h['start_local_date'], 'date_mode' => 'backdate',
        ], occurredAt: $case['now'])])->assertJsonPath('data.acks.0.status', 'accepted');
        $logs = [];
        foreach ($h['logs'] as $date => $value) {
            $logs[] = [
                'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit_log', 'entity_id' => (string) Str::uuid7(),
                'operation' => 'log.set_value', 'base_version' => 0, 'occurred_at' => $case['now'],
                'captured_timezone' => $case['timezone'],
                'payload' => ['habit_id' => $h['id'], 'value' => $value, 'date_mode' => 'backdate', 'log_date' => $date],
            ];
        }
        foreach (array_chunk($logs, 50) as $chunk) {
            $acks = $test->sync($user['token'], $chunk)->json('data.acks');
            expect(array_unique(array_column($acks, 'status')))->toBe(['accepted']);
        }
        if ($h['archived'] ?? false) {
            $version = (int) DB::table('habits')->where('id', $h['id'])->value('version');
            $test->sync($user['token'], [[
                'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit', 'entity_id' => $h['id'],
                'operation' => 'habit.archive', 'base_version' => $version, 'occurred_at' => $case['now'], 'payload' => [],
            ]])->assertJsonPath('data.acks.0.status', 'accepted');
        }
    }

    return $user;
}

function insightsGet(object $test, string $token, array $query): TestResponse
{
    app('auth')->forgetGuards();

    return $test->withToken($token)->getJson('/api/v1/insights?'.http_build_query($query));
}

it('answers every insights fixture case through HTTP', function (array $case) {
    $user = seedInsights($this, $case);

    $data = insightsGet($this, $user['token'], $case['query'])->assertOk()->json('data');

    assertMatchesContract($case['expect'], $data);
    // Spec 06: categories sum to the totals.
    expect(array_sum(array_column($data['by_category'], 'completed')))->toBe($data['totals']['completed'])
        ->and(array_sum(array_column($data['by_category'], 'eligible')))->toBe($data['totals']['eligible']);
    if (isset($case['protected_period'])) {
        expect((bool) DB::table('period_evaluations')->where('period_key', $case['protected_period'])->value('protected'))->toBeTrue();
    }
})->with(fn () => array_map(fn ($c) => [$c], insightsCases()));

it('requires a session', function () {
    $this->getJson('/api/v1/insights?period=week')->assertUnauthorized()->assertJsonPath('error.code', 'unauthenticated');
});

it('never counts another user\'s habits', function () {
    $case = insightsCases()[1]; // the month
    seedInsights($this, $case);
    $bob = $this->registerUser('Bob', timezone: $case['timezone']);

    $data = insightsGet($this, $bob['token'], ['period' => 'month'])->assertOk()->json('data');

    expect($data['totals'])->toBe(['completed' => 0, 'eligible' => 0, 'percent' => null])
        ->and($data['by_category'])->toBe([]);
});

it('refuses a missing or unknown period, an unknown category and any other parameter', function (array $query) {
    $this->freezeClock('2026-05-28T20:00:00Z');
    $maya = $this->registerUser('Maya');

    insightsGet($this, $maya['token'], $query)->assertStatus(422)->assertJsonPath('error.code', 'validation_failed');
})->with([
    'no period' => [[]],
    'a year' => [['period' => 'year']],
    'unknown category' => [['period' => 'week', 'category' => 'fitness']],
    'a date' => [['period' => 'week', 'date' => '2026-05-01']],
]);

it('ends a month window on its own last day (February)', function () {
    $this->freezeClock('2026-02-10T20:00:00Z');
    $maya = $this->registerUser('Maya');

    $window = insightsGet($this, $maya['token'], ['period' => 'month'])->assertOk()->json('data.window');

    expect([$window['start'], $window['end']])->toBe(['2026-02-01', '2026-02-28']);
});
