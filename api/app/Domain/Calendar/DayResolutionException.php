<?php

namespace App\Domain\Calendar;

use DomainException;

/**
 * A date could not be resolved or validated. `reason` is a stable machine code:
 * no_calendar, future_event, event_too_old, timezone_context_mismatch, backdate_future,
 * backdate_too_old.
 */
final class DayResolutionException extends DomainException
{
    public function __construct(
        public readonly string $reason,
        /** For timezone_context_mismatch: the server's calendar entry at the event (A29). */
        public readonly ?CalendarEntry $entry = null,
    ) {
        parent::__construct($reason);
    }
}
