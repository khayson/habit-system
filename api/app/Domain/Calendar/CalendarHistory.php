<?php

namespace App\Domain\Calendar;

use App\Domain\Clock;
use InvalidArgumentException;

/**
 * Calendar changes (D1, A26). Pure: the history comes in, the new history goes out; the
 * application layer persists the difference.
 *
 * - A change (zone and/or day-start offset) is effective at the next local day start in the
 *   calendar in force now, never at the request instant, so a date never goes backwards.
 * - At most one entry is pending (effective after now). A new change replaces it; it never
 *   stacks. Changing back to the calendar in force cancels the pending entry.
 * - The result is a valid TimezoneTimeline (its constructor asserts monotonic dates). For a zone
 *   change of more than 24 hours westward no day start works (the new date is always behind the
 *   old one); that change is refused with DayResolutionException('calendar_change_backwards').
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

        // H1: the first old-calendar day start, from the next one on, at which the new calendar's
        // date is not before the old one. The largest offset gap is 26 hours, so three are enough.
        [$effectiveAt, $timeline] = [null, null];
        for ($k = 1; $k <= 3 && $timeline === null; $k++) {
            $candidate = $current->dayStartAfter($now, $k);
            try {
                $timeline = new TimezoneTimeline([...$settled, new CalendarEntry($candidate, $timezone, $dayStartOffsetMinutes)]);
                $effectiveAt = $candidate;
            } catch (InvalidArgumentException) {
                continue;
            }
        }
        if ($effectiveAt === null || $timeline === null) {
            throw new DayResolutionException('calendar_change_backwards');
        }
        $entry = new CalendarEntry($effectiveAt, $timezone, $dayStartOffsetMinutes);
        $same = count($pending) === 1
            && $pending[0]->timezone === $timezone
            && $pending[0]->dayStartOffsetMinutes === $dayStartOffsetMinutes
            && $pending[0]->effectiveAt == $effectiveAt;
        if ($same) {
            return new CalendarChange($timeline, null, false);
        }

        return new CalendarChange($timeline, $entry, true);
    }
}
