<?php

use App\Domain\Calendar\DayResolver;
use App\Domain\Calendar\LocalDate;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Insights\ConsistencyCalculator;
use App\Domain\Period\PeriodEngine;
use App\Domain\Period\PeriodEvaluation;
use App\Domain\Streak\StreakCalculator;
use App\Infrastructure\FrozenClock;
use Tests\Support\DomainFixtures as F;

/**
 * Evaluate a seed habit from its first eligible date through today.
 *
 * @param  array<string, mixed>  $habit
 * @param  list<array<string, mixed>>  $calendar
 * @param  list<string>  $protected
 * @return list<PeriodEvaluation>
 */
function evaluateSeedHabit(array $habit, array $calendar, string $now, array $protected): array
{
    $types = HabitTypeRegistry::withBuiltins();
    $schedule = F::schedule($habit, $types);
    $today = (new DayResolver(F::timeline($calendar), new FrozenClock($now)))->today();
    $engine = new PeriodEngine($types);
    $periods = $engine->periods($schedule, $schedule->versions[0]->effectiveDate, $today);

    return $engine->evaluate($periods, F::logValues($habit, $types), $today, $protected);
}

it('calculates streaks', function (array $case) {
    $evaluations = evaluateSeedHabit($case['habit'], $case['calendar'], $case['now'], $case['protected']);

    $streak = (new StreakCalculator)->calculate($evaluations);

    expect([$streak->current, $streak->longest, $streak->unit])
        ->toBe([$case['expect']['current'], $case['expect']['longest'], $case['expect']['unit']]);

    $statuses = [];
    foreach ($evaluations as $e) {
        $statuses[$e->period->key] = $e->status->value;
    }
    foreach ($case['expect']['statuses'] as $key => $status) {
        expect($statuses[$key] ?? null)->toBe($status, $key);
    }
})->with(fn () => F::named(F::load('streaks')['cases']));

it('reproduces the spec insights: 95/125 = 76 % for May, 9/15 = 60 % for the week', function () {
    $fixture = F::load('insights');
    $seed = $fixture['seed'];
    $calculator = new ConsistencyCalculator;

    $byCategory = [];
    $all = [];
    foreach ($seed['habits'] as $habit) {
        $evaluations = evaluateSeedHabit($habit, $seed['calendar'], $fixture['now'], $seed['protected']);
        $byCategory[$habit['category']] = array_merge($byCategory[$habit['category']] ?? [], $evaluations);
        $all = array_merge($all, $evaluations);
    }

    foreach (['monthly', 'weekly'] as $window) {
        $from = LocalDate::fromString($fixture[$window]['window']['from']);
        $to = LocalDate::fromString($fixture[$window]['window']['to']);
        $total = $calculator->summarize($all, $from, $to);
        $expected = $fixture[$window]['expect']['total'];

        expect([$total->completed, $total->eligible, $total->percent])
            ->toBe([$expected['completed'], $expected['eligible'], $expected['percent']], $window);

        foreach ($fixture[$window]['expect']['by_category'] ?? [] as $category => $row) {
            $c = $calculator->byCategory($byCategory, $from, $to)[$category];
            expect([$c->completed, $c->eligible, $c->percent])->toBe([$row['completed'], $row['eligible'], $row['percent']], $category);
        }
        if (isset($fixture[$window]['expect']['xp'])) {
            expect($calculator->earnedXp($all, $from, $to))->toBe($fixture[$window]['expect']['xp']);
        }
    }
});

it('rounds percentages half up and leaves an empty window without a percent', function () {
    expect(ConsistencyCalculator::percent(1, 2))->toBe(50)
        ->and(ConsistencyCalculator::percent(37, 54))->toBe(69)
        ->and(ConsistencyCalculator::percent(1, 8))->toBe(13)
        ->and(ConsistencyCalculator::percent(0, 0))->toBeNull();
});
