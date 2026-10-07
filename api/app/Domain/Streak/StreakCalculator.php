<?php

namespace App\Domain\Streak;

use App\Domain\Period\PeriodEvaluation;
use App\Domain\Period\PeriodKind;
use App\Domain\Period\PeriodStatus;

/**
 * Current streak: the suffix of closed eligible periods that are complete or protected, plus the
 * current day period when it is already complete. An unfinished current period leaves the prior
 * streak intact. Weekly streaks grow only when the week closes (spec 08).
 */
final class StreakCalculator
{
    /**
     * @param  list<PeriodEvaluation>  $evaluations  one habit's evaluations, any order
     */
    public function calculate(array $evaluations): StreakResult
    {
        usort($evaluations, fn (PeriodEvaluation $a, PeriodEvaluation $b) => $a->period->startDate->compareTo($b->period->startDate));

        $run = 0;
        $longest = 0;
        $currentPeriod = null;

        foreach ($evaluations as $evaluation) {
            if ($evaluation->closed) {
                $run = $evaluation->keepsStreak() ? $run + 1 : 0;
                $longest = max($longest, $run);
            } elseif ($evaluation->current) {
                $currentPeriod = $evaluation;
            }
        }

        if ($currentPeriod !== null
            && $currentPeriod->period->kind === PeriodKind::Day
            && $currentPeriod->status === PeriodStatus::Complete) {
            $run++;
            $longest = max($longest, $run);
        }

        $last = $evaluations === [] ? null : $evaluations[count($evaluations) - 1];

        return new StreakResult($run, $longest, $last?->period->definition->frequency->streakUnit() ?? 'days');
    }
}
