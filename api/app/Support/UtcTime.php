<?php

namespace App\Support;

use Carbon\CarbonImmutable;
use DateTimeInterface;

final class UtcTime
{
    /** Wire format for instants: ISO-8601, UTC, whole seconds, `Z` suffix. */
    public const string FORMAT = 'Y-m-d\TH:i:s\Z';

    public static function format(DateTimeInterface $instant): string
    {
        return CarbonImmutable::instance($instant)->utc()->format(self::FORMAT);
    }
}
