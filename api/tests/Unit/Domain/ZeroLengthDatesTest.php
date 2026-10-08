<?php

use App\Domain\Calendar\LocalDate;
use App\Domain\Habit\Frequency;
use App\Domain\Habit\HabitSchedule;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Insights\ConsistencyCalculator;
use App\Domain\Period\PeriodEngine;
use App\Domain\Period\PeriodEvaluation;
use App\Domain\Streak\StreakCalculator;
use Tests\Support\DomainFixtures as F;

/*
 * D2 / A30: contract-fixtures/domain/zero_length.json.
 */

$fixture = F::load('zero_length');

it('leaves zero-length dates out of periods, streaks and consistency', function (array $case) {
    $types = HabitTypeRegistry::withBuiltins();
    $engine = new PeriodEngine($types);
    $periods = $engine->periods(
        F::schedule($case['habit'], $types),
        LocalDate::fromString($case['from']),
        LocalDate::fromString($case['to']),
        F::timeline($case['calendar']),
    );
    $evaluations = $engine->evaluate($periods, F::logValues($case['habit'], $types), LocalDate::fromString($case['today']));

    expect(array_map(fn (PeriodEvaluation $e) => [$e->period->key, $e->status->value], $evaluations))
        ->toBe($case['expect']['periods']);

    $streak = (new StreakCalculator)->calculate($evaluations);
    expect(['current' => $streak->current, 'longest' => $streak->longest])->toBe($case['expect']['streak']);

    $consistency = (new ConsistencyCalculator)->summarize($evaluations);
    expect(['completed' => $consistency->completed, 'eligible' => $consistency->eligible, 'percent' => $consistency->percent])
        ->toBe($case['expect']['consistency']);
})->with(F::named($fixture['cases']));

it('starts a new definition tomorrow, or next Monday when either frequency is weekly', function (array $case) {
    $date = HabitSchedule::nextEffectiveDate(
        LocalDate::fromString($case['today']),
        Frequency::fromArray($case['from']['frequency_type'], $case['from']['frequency_config']),
        Frequency::fromArray($case['to']['frequency_type'], $case['to']['frequency_config']),
    );

    expect($date->toString())->toBe($case['expect']);
})->with(F::named($fixture['next_effective_date']));
