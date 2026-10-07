<?php

namespace App\Domain\Calendar;

use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use InvalidArgumentException;

/**
 * One row of a user's calendar history: from `effectiveAt` on, habit days use this IANA zone and
 * start `dayStartOffsetMinutes` after local midnight (A22).
 */
final readonly class CalendarEntry
{
    public const int MAX_DAY_START_OFFSET_MINUTES = 360;

    public DateTimeImmutable $effectiveAt;

    public DateTimeZone $zone;

    public function __construct(
        DateTimeInterface $effectiveAt,
        public string $timezone,
        public int $dayStartOffsetMinutes = 0,
    ) {
        if (! self::isIanaZone($timezone)) {
            throw new InvalidArgumentException("Not an IANA time zone: {$timezone}");
        }
        if ($dayStartOffsetMinutes < 0 || $dayStartOffsetMinutes > self::MAX_DAY_START_OFFSET_MINUTES) {
            throw new InvalidArgumentException('day_start_offset_minutes must be within 0..360');
        }
        $this->effectiveAt = DateTimeImmutable::createFromInterface($effectiveAt)->setTimezone(new DateTimeZone('UTC'));
        $this->zone = new DateTimeZone($timezone);
    }

    /** Named zones only: never fixed offsets ("+02:00") or abbreviations ("PST"). */
    public static function isIanaZone(string $timezone): bool
    {
        return in_array($timezone, DateTimeZone::listIdentifiers(DateTimeZone::ALL_WITH_BC), true);
    }
}
