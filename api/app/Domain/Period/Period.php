<?php

namespace App\Domain\Period;

use App\Domain\Calendar\LocalDate;
use App\Domain\Habit\DefinitionVersion;

/** An eligible scheduled period of one habit. */
final readonly class Period
{
    /**
     * @param  list<LocalDate>  $activeDates  dates inside the period that can count (week: active days)
     */
    public function __construct(
        public string $key,
        public PeriodKind $kind,
        public LocalDate $startDate,
        /** Inclusive. */
        public LocalDate $endDate,
        public DefinitionVersion $definition,
        public array $activeDates,
    ) {}

    public static function dayKey(LocalDate $date): string
    {
        return 'd:'.$date->toString();
    }

    public static function weekKey(LocalDate $monday): string
    {
        return 'w:'.$monday->toString();
    }

    /** Days that must be completed: 1 for a day period, the weekly count for a week. */
    public function requiredDays(): int
    {
        return $this->kind === PeriodKind::Week ? $this->definition->frequency->count : 1;
    }

    public function contains(LocalDate $date): bool
    {
        return ! $date->isBefore($this->startDate) && ! $date->isAfter($this->endDate);
    }
}
