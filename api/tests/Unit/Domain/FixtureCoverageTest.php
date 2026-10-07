<?php

/*
 * Gate guard: every domain fixture that names the php suite is consumed by a test here.
 * Adding a fixture without a consumer fails this test.
 */

const PHP_FIXTURE_CONSUMERS = [
    'day_resolution' => 'DayResolutionTest',
    'periods' => 'PeriodEngineTest',
    'weekly' => 'PeriodEngineTest',
    'streaks' => 'StreakAndInsightsTest',
    'insights' => 'StreakAndInsightsTest',
    'xp' => 'RewardsTest',
    'freezes' => 'RewardsTest',
    'progress' => 'HabitTypesTest',
];

it('consumes every domain fixture that names the php suite', function () {
    $named = [];
    foreach (glob(dirname(__DIR__, 4).'/contract-fixtures/domain/*.json') ?: [] as $path) {
        $fixture = json_decode((string) file_get_contents($path), true, flags: JSON_THROW_ON_ERROR);
        if (in_array('php', $fixture['suites'], true)) {
            $named[] = basename($path, '.json');
        }
    }

    expect($named)->not->toBeEmpty()
        ->and(array_keys(PHP_FIXTURE_CONSUMERS))->toEqualCanonicalizing($named);
    foreach (PHP_FIXTURE_CONSUMERS as $fixture => $test) {
        $source = (string) file_get_contents(__DIR__."/{$test}.php");
        expect($source)->toMatch("/load\\('{$fixture}'\\)/", "{$test} does not load {$fixture}");
    }
});
