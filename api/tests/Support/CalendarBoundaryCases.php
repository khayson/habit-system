<?php

namespace Tests\Support;

use App\Domain\Calendar\CalendarEntry;
use App\Domain\Calendar\CalendarHistory;
use App\Domain\Calendar\DayResolutionException;
use App\Domain\Calendar\TimezoneTimeline;
use App\Infrastructure\FrozenClock;
use App\Support\UtcTime;
use DateTimeImmutable;
use DateTimeZone;

/**
 * H1: the generated part of contract-fixtures/domain/calendar_boundaries.json. Every pair of
 * ZONES at every NOW: the history is one entry of the first zone; the change to the second goes
 * through CalendarHistory::appendChange; the rows are the dates within 3 days of the change.
 */
final class CalendarBoundaryCases
{
    public const array ZONES = [
        'Pacific/Kiritimati', 'Pacific/Auckland', 'Pacific/Apia', 'Pacific/Chatham',
        'Asia/Kathmandu', 'Asia/Kolkata', 'Pacific/Honolulu', 'Pacific/Pago_Pago',
        'America/Los_Angeles', 'Europe/London', 'Africa/Accra', 'Australia/Lord_Howe',
    ];

    /** A US DST day, the EU DST night, the southern autumn change weekend, a plain day. */
    public const array NOWS = ['2026-03-08T09:30:00Z', '2026-03-29T00:30:00Z', '2026-04-04T14:30:00Z', '2026-06-15T12:00:00Z'];

    public const string HISTORY_START = '2025-12-01T00:00:00Z';

    /** @return array<string, mixed> */
    public static function fixture(): array
    {
        return [
            'kind' => 'calendar_boundaries',
            'suites' => ['php', 'dart'],
            'description' => 'H1: day boundaries across zone changes, including changes of 24 hours or more. The start of a date is the first instant whose date is that date or later; a date is zero-length when the date at its start is later; end(d) = start(d+1). A change takes effect at the first old-calendar day start (from the next one on, at most 3) where the new date is not before the old one; a change that can never satisfy that (more than 24 hours westward) is refused. `generated` comes from api/tests/Support/generate_calendar_boundaries.php.',
            'rows' => '[date, start, end, zero_length]',
            'cases' => self::handCases(),
            'generated' => self::generated(),
        ];
    }

    public static function path(): string
    {
        return dirname(__DIR__, 3).'/contract-fixtures/domain/calendar_boundaries.json';
    }

    /** The fixture as written to disk: pretty JSON with one line per row (arrays of scalars). */
    public static function encode(): string
    {
        $json = json_encode(self::fixture(), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)."\n";
        $scalar = '(?:"[^"]*"|true|false|null|-?\d+)';

        return (string) preg_replace_callback(
            '/\[\s*'.$scalar.'(?:\s*,\s*'.$scalar.')*\s*\]/',
            fn (array $m) => '['.trim((string) preg_replace('/\s*,\s*/', ', ', trim($m[0], "[] \n"))).']',
            $json,
        );
    }

    /** @return list<array<string, mixed>> */
    public static function generated(): array
    {
        $cases = [];
        foreach (self::NOWS as $now) {
            foreach (self::ZONES as $from) {
                foreach (self::ZONES as $to) {
                    if ($from !== $to) {
                        $cases[] = self::case($from, $to, $now);
                    }
                }
            }
        }

        return $cases;
    }

    /** @return array<string, mixed> */
    public static function case(string $from, string $to, string $now): array
    {
        $history = new TimezoneTimeline([new CalendarEntry(new DateTimeImmutable(self::HISTORY_START), $from)]);
        try {
            $change = (new CalendarHistory(new FrozenClock($now)))->appendChange($history, $to, 0);
        } catch (DayResolutionException $e) {
            return ['from' => $from, 'to' => $to, 'now' => $now, 'effective_at' => null, 'refused' => $e->reason, 'rows' => []];
        }
        $effective = $change->added?->effectiveAt ?? throw new \LogicException('no entry added');

        return [
            'from' => $from,
            'to' => $to,
            'now' => $now,
            'effective_at' => UtcTime::format($effective),
            'refused' => null,
            'rows' => self::rows($change->timeline, $effective),
        ];
    }

    /** @return list<array{string, string, string, bool}> */
    public static function rows(TimezoneTimeline $timeline, DateTimeImmutable $effective): array
    {
        $around = $timeline->localDateAt($effective->modify('-1 second'));
        $rows = [];
        for ($k = -3; $k <= 3; $k++) {
            $date = $around->addDays($k);
            $rows[] = [
                $date->toString(),
                UtcTime::format($timeline->startOfLocalDay($date)),
                UtcTime::format($timeline->endOfLocalDay($date)),
                $timeline->isZeroLength($date),
            ];
        }

        return $rows;
    }

    /** Offset of a zone at an instant, in seconds. */
    public static function offset(string $zone, string $instant): int
    {
        return (new DateTimeZone($zone))->getOffset(new DateTimeImmutable($instant));
    }

    /** @return list<array<string, mixed>> the review's three cases, values derived by hand */
    private static function handCases(): array
    {
        return [
            [
                'name' => 'Pago_Pago to Kiritimati at 2026-03-10T11:00Z: 9 March jumps to 11 March, so 10 March is zero-length',
                'calendar' => [
                    ['effective_at' => '2026-01-01T00:00:00Z', 'timezone' => 'Pacific/Pago_Pago', 'day_start_offset_minutes' => 0],
                    ['effective_at' => '2026-03-10T11:00:00Z', 'timezone' => 'Pacific/Kiritimati', 'day_start_offset_minutes' => 0],
                ],
                'rows' => [
                    ['2026-03-09', '2026-03-09T11:00:00Z', '2026-03-10T11:00:00Z', false],
                    ['2026-03-10', '2026-03-10T11:00:00Z', '2026-03-10T11:00:00Z', true],
                    ['2026-03-11', '2026-03-10T11:00:00Z', '2026-03-11T10:00:00Z', false],
                    ['2026-03-12', '2026-03-11T10:00:00Z', '2026-03-12T10:00:00Z', false],
                ],
            ],
            [
                'name' => 'Auckland to Pago_Pago at 2026-03-10T11:00Z (24 hours west): 10 March runs 48 hours from its Auckland start',
                'calendar' => [
                    ['effective_at' => '2026-01-01T00:00:00Z', 'timezone' => 'Pacific/Auckland', 'day_start_offset_minutes' => 0],
                    ['effective_at' => '2026-03-10T11:00:00Z', 'timezone' => 'Pacific/Pago_Pago', 'day_start_offset_minutes' => 0],
                ],
                'rows' => [
                    ['2026-03-09', '2026-03-08T11:00:00Z', '2026-03-09T11:00:00Z', false],
                    ['2026-03-10', '2026-03-09T11:00:00Z', '2026-03-11T11:00:00Z', false],
                    ['2026-03-11', '2026-03-11T11:00:00Z', '2026-03-12T11:00:00Z', false],
                ],
            ],
            [
                'name' => 'Kiritimati to Pago_Pago (25 hours west) can never keep dates monotonic: refused, never a server error',
                'change' => ['history' => 'Pacific/Kiritimati', 'to' => 'Pacific/Pago_Pago', 'now' => '2026-03-09T12:00:00Z'],
                'refused' => 'calendar_change_backwards',
            ],
        ];
    }
}
