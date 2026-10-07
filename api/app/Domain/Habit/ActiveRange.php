<?php

namespace App\Domain\Habit;

use App\Domain\Calendar\LocalDate;
use InvalidArgumentException;

/** Half-open active local-date range [startsOn, endsBefore); endsBefore null = still active. */
final readonly class ActiveRange
{
    public function __construct(
        public LocalDate $startsOn,
        public ?LocalDate $endsBefore = null,
    ) {
        if ($endsBefore !== null && ! $endsBefore->isAfter($startsOn)) {
            throw new InvalidArgumentException('An active range must end after it starts.');
        }
    }

    public function contains(LocalDate $date): bool
    {
        return ! $date->isBefore($this->startsOn)
            && ($this->endsBefore === null || $date->isBefore($this->endsBefore));
    }
}
