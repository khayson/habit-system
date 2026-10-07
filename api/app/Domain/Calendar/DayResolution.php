<?php

namespace App\Domain\Calendar;

/**
 * Canonical business date of an event, plus the calendar entry it was resolved with (logs freeze
 * `resolved_timezone` and the offset alongside the date, A22).
 */
final readonly class DayResolution
{
    public function __construct(
        public LocalDate $localDate,
        public CalendarEntry $entry,
        /** null when the client sent no hint; false when the trusted timeline overrode it. */
        public ?bool $hintMatches,
    ) {}
}
