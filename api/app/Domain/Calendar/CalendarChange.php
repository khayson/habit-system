<?php

namespace App\Domain\Calendar;

/** The outcome of CalendarHistory::appendChange. */
final readonly class CalendarChange
{
    public function __construct(
        /** The whole history after the change (settled entries plus at most one pending). */
        public TimezoneTimeline $timeline,
        /** The new pending entry, or null when the change only cancelled one or did nothing. */
        public ?CalendarEntry $added,
        /** Whether the stored history must change. */
        public bool $changed,
    ) {}
}
