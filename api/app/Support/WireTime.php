<?php

namespace App\Support;

use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;

/**
 * Client-supplied instants (occurred_at) keep their full precision on the wire; server-generated
 * instants use UtcTime (whole seconds). Both are UTC with a `Z` suffix.
 */
final class WireTime
{
    public static function precise(DateTimeInterface $instant): string
    {
        $utc = DateTimeImmutable::createFromInterface($instant)->setTimezone(new DateTimeZone('UTC'));
        $micro = rtrim($utc->format('u'), '0');

        return $utc->format('Y-m-d\TH:i:s').($micro === '' ? '' : '.'.$micro).'Z';
    }

    /** Parses a stored timestamptz or an ISO-8601 instant. */
    public static function parse(string $value): DateTimeImmutable
    {
        return (new DateTimeImmutable($value))->setTimezone(new DateTimeZone('UTC'));
    }

    /** Value for a timestamptz column, keeping microseconds. */
    public static function forDatabase(DateTimeInterface $instant): string
    {
        return DateTimeImmutable::createFromInterface($instant)->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s.uP');
    }
}
