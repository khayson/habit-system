<?php

namespace App\Application\Calendar;

use App\Domain\Calendar\CalendarEntry;
use App\Domain\Calendar\TimezoneTimeline;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;
use stdClass;

/** Loads a user's calendar history (timezone + day-start offset, A22) into the domain. */
final class UserCalendar
{
    public static function timeline(string $userId): TimezoneTimeline
    {
        $rows = DB::table('user_timezone_history')
            ->where('user_id', $userId)
            ->orderBy('effective_at')
            ->get(['timezone', 'day_start_offset_minutes', 'effective_at']);

        return new TimezoneTimeline(array_values($rows->map(fn (stdClass $row) => new CalendarEntry(
            new DateTimeImmutable((string) $row->effective_at),
            (string) $row->timezone,
            (int) $row->day_start_offset_minutes,
        ))->all()));
    }
}
