<?php

use App\Domain\Calendar\CalendarEntry;
use App\Domain\Calendar\CalendarHistory;
use App\Domain\Calendar\DayResolutionException;
use App\Domain\Calendar\LocalDate;
use App\Domain\Calendar\TimezoneTimeline;
use App\Infrastructure\FrozenClock;
use App\Support\UtcTime;
use Tests\Support\CalendarBoundaryCases;
use Tests\Support\DomainFixtures as F;

/*
 * H1: contract-fixtures/domain/calendar_boundaries.json, plus the property over every pair.
 */

$fixture = F::load('calendar_boundaries');

it('keeps the committed fixture in step with its generator', function () {
    expect((string) file_get_contents(CalendarBoundaryCases::path()))->toBe(CalendarBoundaryCases::encode());
});

it('pins the hand-derived cases', function (array $case) {
    if (isset($case['refused'])) {
        $history = new TimezoneTimeline([new CalendarEntry(new DateTimeImmutable(CalendarBoundaryCases::HISTORY_START), $case['change']['history'])]);
        expect(fn () => (new CalendarHistory(new FrozenClock($case['change']['now'])))->appendChange($history, $case['change']['to'], 0))
            ->toThrow(DayResolutionException::class, $case['refused']);

        return;
    }
    $timeline = F::timeline($case['calendar']);
    foreach ($case['rows'] as [$date, $start, $end, $zero]) {
        $d = LocalDate::fromString($date);
        expect([UtcTime::format($timeline->startOfLocalDay($d)), UtcTime::format($timeline->endOfLocalDay($d)), $timeline->isZeroLength($d)])
            ->toBe([$start, $end, $zero], $date);
    }
})->with(F::named($fixture['cases']));

it('holds the boundary properties for every zone pair and instant (H1)', function (string $now) {
    foreach (CalendarBoundaryCases::ZONES as $from) {
        foreach (CalendarBoundaryCases::ZONES as $to) {
            if ($from === $to) {
                continue;
            }
            $label = "{$from} -> {$to} at {$now}";
            $history = new TimezoneTimeline([new CalendarEntry(new DateTimeImmutable(CalendarBoundaryCases::HISTORY_START), $from)]);
            $westward = CalendarBoundaryCases::offset($from, $now) - CalendarBoundaryCases::offset($to, $now);
            try {
                $change = (new CalendarHistory(new FrozenClock($now)))->appendChange($history, $to, 0);
            } catch (DayResolutionException $e) {
                // Only a change of more than 24 hours westward can never keep dates monotonic.
                expect($e->reason)->toBe('calendar_change_backwards', $label)
                    ->and($westward)->toBeGreaterThan(86400, $label);

                continue;
            }
            expect($westward)->toBeLessThanOrEqual(86400, $label);
            $timeline = $change->timeline;
            $effective = $change->added?->effectiveAt ?? throw new LogicException($label);
            expect($effective > new DateTimeImmutable($now))->toBeTrue($label);

            $around = $timeline->localDateAt($effective->modify('-1 second'));
            for ($k = -3; $k <= 3; $k++) {
                $date = $around->addDays($k);
                $start = $timeline->startOfLocalDay($date);
                $end = $timeline->endOfLocalDay($date);
                if ($timeline->isZeroLength($date)) {
                    // No instant maps to it.
                    expect($timeline->localDateAt($start)->isAfter($date))->toBeTrue("{$label} {$date->toString()}");

                    continue;
                }
                expect($timeline->localDateAt($start)->equals($date))->toBeTrue("{$label} {$date->toString()} start")
                    ->and($timeline->localDateAt($start->modify('-1 second'))->isBefore($date))->toBeTrue("{$label} {$date->toString()} before")
                    ->and($timeline->localDateAt($end->modify('-1 second'))->equals($date))->toBeTrue("{$label} {$date->toString()} end");
            }

            // Dates never go backwards across the change.
            $previous = null;
            for ($t = $effective->modify('-3 days'); $t < $effective->modify('+3 days'); $t = $t->modify('+15 minutes')) {
                $date = $timeline->localDateAt($t);
                expect($previous === null || ! $date->isBefore($previous))->toBeTrue("{$label} at {$t->format('c')}");
                $previous = $date;
            }
        }
    }
})->with(CalendarBoundaryCases::NOWS);
