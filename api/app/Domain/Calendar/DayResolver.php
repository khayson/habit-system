<?php

namespace App\Domain\Calendar;

use App\Domain\Clock;
use DateInterval;
use DateTimeInterface;

/**
 * Resolves a habit date from occurred_at using the user's calendar history, never from receipt
 * time, server "today" or an unchecked client date (invariant 3, spec 08).
 */
final readonly class DayResolver
{
    public const int FUTURE_TOLERANCE_SECONDS = 300;

    public const int MAX_OFFLINE_AGE_SECONDS = 90 * 86400;

    public const int MAX_BACKDATE_DAYS = 30;

    public function __construct(
        private TimezoneTimeline $timeline,
        private Clock $clock,
    ) {}

    /**
     * @param  string|null  $capturedTimezone  the habit-calendar zone the client used (A5)
     *
     * @throws DayResolutionException
     */
    public function resolve(DateTimeInterface $occurredAt, ?string $capturedTimezone = null, ?LocalDate $localDateHint = null): DayResolution
    {
        $entry = $this->timeline->entryAt($occurredAt);
        $now = $this->clock->now();

        if ($occurredAt > $now->add(new DateInterval('PT'.self::FUTURE_TOLERANCE_SECONDS.'S'))) {
            throw new DayResolutionException('future_event');
        }
        if ($occurredAt < $now->sub(new DateInterval('PT'.self::MAX_OFFLINE_AGE_SECONDS.'S'))) {
            throw new DayResolutionException('event_too_old');
        }
        if ($capturedTimezone !== null && $capturedTimezone !== $entry->timezone) {
            throw new DayResolutionException('timezone_context_mismatch');
        }

        $date = $this->timeline->localDateAt($occurredAt);

        return new DayResolution($date, $entry, $localDateHint?->equals($date));
    }

    /** The user's current business date. */
    public function today(): LocalDate
    {
        return $this->timeline->localDateAt($this->clock->now());
    }

    /**
     * Explicit backdate mode: a validated local date, at most 30 days back, never in the future.
     * It does not invent an event timestamp. (Active-range checks belong to the period engine.)
     *
     * @throws DayResolutionException
     */
    public function validateBackdate(LocalDate $date): void
    {
        $today = $this->today();
        if ($date->isAfter($today)) {
            throw new DayResolutionException('backdate_future');
        }
        if ($date->daysUntil($today) > self::MAX_BACKDATE_DAYS) {
            throw new DayResolutionException('backdate_too_old');
        }
    }
}
