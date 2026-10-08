<?php

namespace App\Domain\Habit;

use App\Domain\Calendar\LocalDate;
use InvalidArgumentException;

/** A habit's definition history and active ranges: everything eligibility depends on. */
final readonly class HabitSchedule
{
    /**
     * @param  list<DefinitionVersion>  $versions  ascending effective dates, unique (A4)
     * @param  list<ActiveRange>  $ranges  ascending, non-overlapping
     */
    public function __construct(
        public string $habitId,
        public array $versions,
        public array $ranges,
    ) {
        if ($versions === []) {
            throw new InvalidArgumentException('A habit needs at least one definition version.');
        }
        for ($i = 1, $n = count($versions); $i < $n; $i++) {
            if (! $versions[$i]->effectiveDate->isAfter($versions[$i - 1]->effectiveDate)
                || $versions[$i]->version <= $versions[$i - 1]->version) {
                throw new InvalidArgumentException('Definition versions must increase in version and effective date.');
            }
            if ($versions[$i]->type !== $versions[0]->type) {
                throw new InvalidArgumentException('A habit type is immutable (A4).');
            }
        }
        for ($i = 1, $n = count($ranges); $i < $n; $i++) {
            $previousEnd = $ranges[$i - 1]->endsBefore;
            if ($previousEnd === null || $ranges[$i]->startsOn->isBefore($previousEnd)) {
                throw new InvalidArgumentException('Active ranges must be ordered and non-overlapping.');
            }
        }
    }

    /** The definition governing a date, or null before the habit's first version. */
    public function versionOn(LocalDate $date): ?DefinitionVersion
    {
        $found = null;
        foreach ($this->versions as $version) {
            if (! $version->effectiveDate->isAfter($date)) {
                $found = $version;
            }
        }

        return $found;
    }

    public function isActive(LocalDate $date): bool
    {
        foreach ($this->ranges as $range) {
            if ($range->contains($date)) {
                return true;
            }
        }

        return false;
    }

    /** Active and governed by a definition: the date can take part in a period. */
    public function isEligible(LocalDate $date): bool
    {
        return $this->isActive($date) && $this->versionOn($date) !== null;
    }

    /**
     * The first date a new definition may govern (A30): tomorrow, or the next Monday when either
     * the old or the new frequency is weekly, so a change never leaves days outside every period
     * and never splits an open week.
     */
    public static function nextEffectiveDate(LocalDate $today, Frequency $old, Frequency $new): LocalDate
    {
        if ($old->isWeekly() || $new->isWeekly()) {
            return $today->mondayOfWeek()->addDays(7);
        }

        return $today->addDays(1);
    }

    public function latest(): DefinitionVersion
    {
        return $this->versions[count($this->versions) - 1];
    }
}
