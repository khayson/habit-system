<?php

use App\Domain\Calendar\LocalDate;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Period\Period;
use App\Domain\Period\PeriodEngine;
use Tests\Support\DomainFixtures as F;

/** contract-fixtures/domain/periods.json and weekly.json */
function engine(): PeriodEngine
{
    return new PeriodEngine(HabitTypeRegistry::withBuiltins());
}

it('lists eligible periods', function (array $case) {
    $schedule = F::schedule($case['habit'], HabitTypeRegistry::withBuiltins());

    $rows = array_map(
        fn (Period $p) => [$p->key, $p->startDate->toString(), $p->endDate->toString(), $p->definition->version],
        engine()->periods($schedule, LocalDate::fromString($case['from']), LocalDate::fromString($case['to'])),
    );

    expect($rows)->toBe($case['expect']);
})->with(fn () => F::named(F::load('periods')['periods']));

it('bounds periods by local day starts', function (array $case) {
    $schedule = F::schedule($case['habit'], HabitTypeRegistry::withBuiltins());
    $key = $case['period_key'];
    $start = LocalDate::fromString(substr($key, 2));
    $periods = array_values(array_filter(
        engine()->periods($schedule, $start, $start->addDays(6)),
        fn (Period $p) => $p->key === $key,
    ));

    [$startsAt, $endsAt] = engine()->bounds($periods[0], F::timeline($case['calendar']));

    expect($startsAt->format('Y-m-d\TH:i:s\Z'))->toBe($case['starts_at'])
        ->and($endsAt->format('Y-m-d\TH:i:s\Z'))->toBe($case['ends_at']);
})->with(fn () => F::named(F::load('periods')['boundaries']));

it('evaluates periods against logs', function (array $case) {
    $types = HabitTypeRegistry::withBuiltins();
    $schedule = F::schedule($case['habit'], $types);
    $periods = engine()->periods($schedule, LocalDate::fromString($case['from']), LocalDate::fromString($case['to']));

    $rows = array_map(
        fn ($e) => [$e->period->key, $e->status->value, $e->closed],
        engine()->evaluate($periods, F::logValues($case['habit'], $types), LocalDate::fromString($case['today']), $case['protected']),
    );

    expect($rows)->toBe($case['expect']);
})->with(fn () => F::named(F::load('periods')['evaluation']));

it('counts distinct completed days for weekly targets', function (array $case) {
    $types = HabitTypeRegistry::withBuiltins();
    $schedule = F::schedule($case['habit'], $types);
    $monday = LocalDate::fromString(substr($case['period_key'], 2));
    $periods = engine()->periods($schedule, $monday, $monday->addDays(6));

    expect($periods)->toHaveCount(1);
    [$evaluation] = engine()->evaluate($periods, F::logValues($case['habit'], $types), LocalDate::fromString($case['today']));

    expect($evaluation->period->key)->toBe($case['period_key'])
        ->and($evaluation->status->value)->toBe($case['expect']['status'])
        ->and($evaluation->closed)->toBe($case['expect']['closed'])
        ->and($evaluation->completedDays)->toBe($case['expect']['completed_days'])
        ->and($evaluation->period->requiredDays())->toBe($case['provisional']['target_days']);
})->with(fn () => F::named(F::load('weekly')['cases']));
