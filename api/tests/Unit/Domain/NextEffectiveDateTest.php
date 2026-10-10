<?php

use App\Domain\Calendar\LocalDate;
use App\Domain\Habit\Frequency;
use App\Domain\Habit\HabitSchedule;

/*
 * A30, A34: contract-fixtures/habit/next_effective_date.json, the first date a new definition
 * may govern.
 */

it('picks the first date a new definition may govern', function (array $case) {
    $frequency = fn (array $f) => Frequency::fromArray($f['frequency_type'], $f['frequency_config']);

    $date = HabitSchedule::nextEffectiveDate(
        LocalDate::fromString($case['today']),
        $frequency($case['old']),
        $frequency($case['new']),
    );

    expect($date->toString())->toBe($case['expect']);
})->with(function () {
    $fixture = json_decode((string) file_get_contents(dirname(__DIR__, 4).'/contract-fixtures/habit/next_effective_date.json'), true, flags: JSON_THROW_ON_ERROR);
    foreach ($fixture['cases'] as $i => $case) {
        yield "{$i}: {$case['old']['frequency_type']} -> {$case['new']['frequency_type']} on {$case['today']}" => [$case];
    }
});
