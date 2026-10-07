<?php

namespace App\Domain\Insights;

use App\Domain\Calendar\LocalDate;
use App\Domain\Period\PeriodEvaluation;
use App\Domain\Period\PeriodStatus;
use App\Domain\Reward\XpRules;

/**
 * Consistency = completed closed eligible periods / all closed eligible periods (spec 03, 10).
 * Open, future, not-due and archived dates never enter the denominator. A protected (frozen)
 * period counts in the denominator but never as a success.
 */
final class ConsistencyCalculator
{
    /**
     * @param  list<PeriodEvaluation>  $evaluations
     */
    public function summarize(array $evaluations, ?LocalDate $from = null, ?LocalDate $to = null): Consistency
    {
        $completed = 0;
        $eligible = 0;
        foreach (self::closedInWindow($evaluations, $from, $to) as $evaluation) {
            $eligible++;
            if ($evaluation->status === PeriodStatus::Complete) {
                $completed++;
            }
        }

        return new Consistency($completed, $eligible, self::percent($completed, $eligible));
    }

    /**
     * Category totals (spec 06: category values sum to the total).
     *
     * @param  array<string, list<PeriodEvaluation>>  $evaluationsByCategory
     * @return array<string, Consistency>
     */
    public function byCategory(array $evaluationsByCategory, ?LocalDate $from = null, ?LocalDate $to = null): array
    {
        return array_map(fn (array $evaluations) => $this->summarize($evaluations, $from, $to), $evaluationsByCategory);
    }

    /**
     * XP from completed days in closed periods of the window (design 14: "+90 XP through 27 May").
     * A weekly habit earns per distinct completed day, with no weekly bonus.
     *
     * @param  list<PeriodEvaluation>  $evaluations
     */
    public function earnedXp(array $evaluations, ?LocalDate $from = null, ?LocalDate $to = null): int
    {
        $days = 0;
        foreach (self::closedInWindow($evaluations, $from, $to) as $evaluation) {
            $days += $evaluation->completedDays;
        }

        return $days * XpRules::XP_PER_COMPLETION;
    }

    public static function percent(int $completed, int $eligible): ?int
    {
        return $eligible === 0 ? null : intdiv(200 * $completed + $eligible, 2 * $eligible);
    }

    /**
     * A period belongs to the window that contains its start date. ASSUMPTION(A1-window).
     *
     * @param  list<PeriodEvaluation>  $evaluations
     * @return iterable<PeriodEvaluation>
     */
    private static function closedInWindow(array $evaluations, ?LocalDate $from, ?LocalDate $to): iterable
    {
        foreach ($evaluations as $evaluation) {
            $start = $evaluation->period->startDate;
            if (! $evaluation->closed
                || ($from !== null && $start->isBefore($from))
                || ($to !== null && $start->isAfter($to))) {
                continue;
            }
            yield $evaluation;
        }
    }
}
