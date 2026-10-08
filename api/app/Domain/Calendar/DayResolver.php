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
        $this->assertWithinBounds($occurredAt);
        $date = $this->timeline->localDateAt($occurredAt);

        // A29: a different captured zone is fine when the client's date already agrees with
        // the server's; the server still resolves the date (invariant 3). Otherwise review.
        if ($capturedTimezone !== null && $capturedTimezone !== $entry->timezone
            && ($localDateHint === null || ! $localDateHint->equals($date))) {
            throw new DayResolutionException('timezone_context_mismatch', $entry);
        }

        return new DayResolution($date, $entry, $localDateHint?->equals($date));
    }

    /**
     * Explicit backdate for a log (spec 08): the client names the local date; occurred_at stays
     * the real moment of the action and is still bounded (5 minutes ahead, 90 days back). The
     * date is checked against the user's local today at occurred_at. The captured zone is not
     * compared, because the date is explicit rather than derived.
     *
     * @throws DayResolutionException
     */
    public function resolveBackdate(LocalDate $date, DateTimeInterface $occurredAt): DayResolution
    {
        $this->assertWithinBounds($occurredAt);
        $this->validateBackdate($date, $occurredAt);

        return new DayResolution($date, $this->timeline->entryForDate($date), null);
    }

    /**
     * occurred_at may be at most 5 minutes ahead of the server and at most 90 days old (spec 08).
     *
     * @throws DayResolutionException
     */
    private function assertWithinBounds(DateTimeInterface $occurredAt): void
    {
        $now = $this->clock->now();
        if ($occurredAt > $now->add(new DateInterval('PT'.self::FUTURE_TOLERANCE_SECONDS.'S'))) {
            throw new DayResolutionException('future_event');
        }
        if ($occurredAt < $now->sub(new DateInterval('PT'.self::MAX_OFFLINE_AGE_SECONDS.'S'))) {
            throw new DayResolutionException('event_too_old');
        }
    }

    /** The user's current business date. */
    public function today(): LocalDate
    {
        return $this->timeline->localDateAt($this->clock->now());
    }

    /**
     * Explicit backdate mode: a validated local date, at most 30 days back, never in the future.
     * It does not invent an event timestamp. (Active-range checks belong to the period engine.)
     * "Today" is the user's local date at $at (a log's occurred_at), or now.
     *
     * @throws DayResolutionException
     */
    public function validateBackdate(LocalDate $date, ?DateTimeInterface $at = null): void
    {
        $today = $at === null ? $this->today() : $this->timeline->localDateAt($at);
        if ($date->isAfter($today)) {
            throw new DayResolutionException('backdate_future');
        }
        if ($date->daysUntil($today) > self::MAX_BACKDATE_DAYS) {
            throw new DayResolutionException('backdate_too_old');
        }
    }
}
