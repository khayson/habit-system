<?php

namespace App\Domain\Period;

final readonly class PeriodEvaluation
{
    public function __construct(
        public Period $period,
        public PeriodStatus $status,
        /** The period's last local day is before today. */
        public bool $closed,
        /** Today falls inside the period. */
        public bool $current,
        /** Distinct local days that met the per-day target. */
        public int $completedDays,
    ) {}

    /** Closed and eligible: enters consistency denominators. */
    public function countsAsClosed(): bool
    {
        return $this->closed;
    }

    public function keepsStreak(): bool
    {
        return $this->status === PeriodStatus::Complete || $this->status === PeriodStatus::Protected;
    }
}
