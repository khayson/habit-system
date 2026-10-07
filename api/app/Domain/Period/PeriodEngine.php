<?php

namespace App\Domain\Period;

use App\Domain\Calendar\LocalDate;
use App\Domain\Calendar\TimezoneTimeline;
use App\Domain\Habit\HabitSchedule;
use App\Domain\Habit\HabitTypeRegistry;
use DateTimeImmutable;

/**
 * Turns a habit's schedule into eligible periods and evaluates them against logs.
 *
 * - Only dates inside active ranges and on or after the first definition are eligible; archived
 *   gaps are never misses.
 * - Each date uses the definition effective on it; a new target never reinterprets older logs.
 * - Weekly periods are Monday-Sunday local weeks keyed by their Monday (A3). A week is governed
 *   by the definition of its first active day, and is due only when the habit is active on at
 *   least `count` of its days. ASSUMPTION(A1-week-partial).
 * - Day boundaries (and so the day-start offset, A22) come from the calendar history.
 */
final readonly class PeriodEngine
{
    public function __construct(private HabitTypeRegistry $types) {}

    /**
     * Eligible periods overlapping [from, to], ordered by start date.
     *
     * @return list<Period>
     */
    public function periods(HabitSchedule $schedule, LocalDate $from, LocalDate $to): array
    {
        $periods = [];

        for ($date = $from; ! $date->isAfter($to); $date = $date->addDays(1)) {
            $definition = $schedule->versionOn($date);
            if ($definition === null || ! $schedule->isActive($date)
                || $definition->frequency->isWeekly() || ! $definition->frequency->schedules($date)) {
                continue;
            }
            $periods[] = new Period(Period::dayKey($date), PeriodKind::Day, $date, $date, $definition, [$date]);
        }

        for ($monday = $from->mondayOfWeek(); ! $monday->isAfter($to); $monday = $monday->addDays(7)) {
            $active = [];
            for ($i = 0; $i < 7; $i++) {
                $day = $monday->addDays($i);
                if ($schedule->isEligible($day)) {
                    $active[] = $day;
                }
            }
            if ($active === []) {
                continue;
            }
            $definition = $schedule->versionOn($active[0]);
            if ($definition === null || ! $definition->frequency->isWeekly() || count($active) < $definition->frequency->count) {
                continue;
            }
            $periods[] = new Period(Period::weekKey($monday), PeriodKind::Week, $monday, $monday->addDays(6), $definition, $active);
        }

        usort($periods, fn (Period $a, Period $b) => $a->startDate->compareTo($b->startDate) ?: strcmp($a->key, $b->key));

        return $periods;
    }

    /**
     * @param  list<Period>  $periods
     * @param  array<string, int>  $logValues  local date (Y-m-d) => stored value in type units
     * @param  list<string>  $protectedKeys  period keys with an active freeze usage
     * @return list<PeriodEvaluation>
     */
    public function evaluate(array $periods, array $logValues, LocalDate $today, array $protectedKeys = []): array
    {
        $protected = array_flip($protectedKeys);

        return array_map(function (Period $period) use ($logValues, $today, $protected): PeriodEvaluation {
            $type = $this->types->get($period->definition->type);
            $completedDays = 0;
            foreach ($period->activeDates as $date) {
                $value = $logValues[$date->toString()] ?? null;
                if ($value !== null && $type->isComplete($value, $period->definition->target)) {
                    $completedDays++;
                }
            }

            $closed = $period->endDate->isBefore($today);
            $status = match (true) {
                $completedDays >= $period->requiredDays() => PeriodStatus::Complete,
                ! $closed => PeriodStatus::Pending,
                isset($protected[$period->key]) => PeriodStatus::Protected,
                default => PeriodStatus::Missed,
            };

            return new PeriodEvaluation($period, $status, $closed, $period->contains($today), $completedDays);
        }, $periods);
    }

    /**
     * UTC instants bounding a period: [startsAt, endsAt). Used for closure order (A8) and for
     * period_evaluations.starts_at / ends_at.
     *
     * @return array{DateTimeImmutable, DateTimeImmutable}
     */
    public function bounds(Period $period, TimezoneTimeline $timeline): array
    {
        return [$timeline->startOfLocalDay($period->startDate), $timeline->endOfLocalDay($period->endDate)];
    }
}
