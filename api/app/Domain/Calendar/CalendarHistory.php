<?php

namespace App\Domain\Calendar;

use App\Domain\Clock;

/**
 * Calendar changes (D1, A26). Pure: the history comes in, the new history goes out; the
 * application layer persists the difference.
 *
 * - A change (zone and/or day-start offset) is effective at the next local day start in the
 *   calendar in force now, never at the request instant, so a date never goes backwards.
 * - At most one entry is pending (effective after now). A new change replaces it; it never
 *   stacks. Changing back to the calendar in force cancels the pending entry.
 * - The result is a valid TimezoneTimeline (its constructor asserts monotonic dates).
 */
final readonly class CalendarHistory
{
    public function __construct(private Clock $clock) {}

    public function appendChange(TimezoneTimeline $timeline, string $timezone, int $dayStartOffsetMinutes): CalendarChange
    {
        $now = $this->clock->now();
        $settled = array_values(array_filter($timeline->entries, fn (CalendarEntry $e) => $e->effectiveAt <= $now));
        $pending = array_values(array_filter($timeline->entries, fn (CalendarEntry $e) => $e->effectiveAt > $now));
        if ($settled === []) {
            throw new DayResolutionException('no_calendar');
        }
        $current = new TimezoneTimeline($settled);
        $inForce = $current->entryAt($now);

        if ($inForce->timezone === $timezone && $inForce->dayStartOffsetMinutes === $dayStartOffsetMinutes) {
            // Back to (or still on) the calendar in force: drop any pending change.
            return new CalendarChange($current, null, $pending !== []);
        }

        $effectiveAt = $current->startOfLocalDay($current->localDateAt($now)->addDays(1));
        $entry = new CalendarEntry($effectiveAt, $timezone, $dayStartOffsetMinutes);
        $same = count($pending) === 1
            && $pending[0]->timezone === $timezone
            && $pending[0]->dayStartOffsetMinutes === $dayStartOffsetMinutes
            && $pending[0]->effectiveAt == $effectiveAt;
        if ($same) {
            return new CalendarChange($timeline, null, false);
        }

        return new CalendarChange(new TimezoneTimeline([...$settled, $entry]), $entry, true);
    }
}
