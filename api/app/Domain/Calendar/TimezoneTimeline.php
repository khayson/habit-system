<?php

namespace App\Domain\Calendar;

use DateTimeImmutable;
use DateTimeInterface;
use DateTimeZone;
use InvalidArgumentException;

/**
 * A user's ordered calendar history (timezone + day-start offset, effective-dated; spec 02, A22).
 *
 * Rules (pinned by contract-fixtures/domain/day_resolution.json):
 * - Day start: the first instant whose wall clock shows 00:00 + offset. If that wall time falls
 *   in a DST gap, the transition instant (the first valid instant after the gap).
 * - Event date: the latest local date whose start is at or before the instant, under the entry
 *   effective at that instant (the first entry governs earlier instants). Dates never go
 *   backwards, even inside a repeated hour or across a zone change (A26).
 * - Period boundaries: a date's start uses the latest entry effective at or before that start,
 *   so a zone change never rewrites days that began earlier.
 * - Monotonic (A26, D1): construction fails if any change would move a date backwards. A change
 *   effective at the next local day start in the old calendar never does; one at an arbitrary
 *   instant can. A change may skip dates forwards (a zero-length date, A30).
 */
final readonly class TimezoneTimeline
{
    /** @var list<CalendarEntry> */
    public array $entries;

    /**
     * @param  list<CalendarEntry>  $entries  in ascending effectiveAt order
     */
    public function __construct(array $entries)
    {
        for ($i = 1, $n = count($entries); $i < $n; $i++) {
            if ($entries[$i]->effectiveAt <= $entries[$i - 1]->effectiveAt) {
                throw new InvalidArgumentException('Calendar entries must have strictly increasing effective_at.');
            }
            $before = self::dateUnder($entries[$i - 1], $entries[$i]->effectiveAt->modify('-1 second'));
            $after = self::dateUnder($entries[$i], $entries[$i]->effectiveAt);
            if ($after->isBefore($before)) {
                throw new InvalidArgumentException(sprintf(
                    'Calendar change at %s would move dates backwards (%s to %s).',
                    $entries[$i]->effectiveAt->format('Y-m-d\TH:i:s\Z'),
                    $before->toString(),
                    $after->toString(),
                ));
            }
        }
        $this->entries = $entries;
    }

    /**
     * The entry in force at an instant. The first entry also governs earlier instants, so a
     * phone clock running slightly behind at signup still resolves (A26). Only an empty history
     * has no calendar.
     */
    public function entryAt(DateTimeInterface $instant): CalendarEntry
    {
        $found = $this->entries[0] ?? throw new DayResolutionException('no_calendar');
        foreach ($this->entries as $entry) {
            if ($entry->effectiveAt <= $instant) {
                $found = $entry;
            }
        }

        return $found;
    }

    /** The business date an instant belongs to. */
    public function localDateAt(DateTimeInterface $instant): LocalDate
    {
        return self::dateUnder($this->entryAt($instant), $instant);
    }

    /**
     * A date with no instants: a calendar change (or the zone's own history, e.g. Pacific/Apia
     * on 2011-12-30) skipped it. It is not part of the period grid (A30).
     */
    public function isZeroLength(LocalDate $date): bool
    {
        return $this->endOfLocalDay($date) <= $this->startOfLocalDay($date);
    }

    /** The date of an instant under one entry. */
    private static function dateUnder(CalendarEntry $entry, DateTimeInterface $instant): LocalDate
    {
        $wall = DateTimeImmutable::createFromInterface($instant)
            ->setTimezone($entry->zone)
            ->modify("-{$entry->dayStartOffsetMinutes} minutes");
        $date = LocalDate::fromString($wall->format('Y-m-d'));

        // The wall-clock guess can be off by one inside DST gaps and repeats; boundaries decide.
        if (self::startFor($date->addDays(1), $entry) <= $instant) {
            return $date->addDays(1);
        }
        if (self::startFor($date, $entry) > $instant) {
            return $date->addDays(-1);
        }

        return $date;
    }

    /** First instant of a business date (UTC). */
    public function startOfLocalDay(LocalDate $date): DateTimeImmutable
    {
        foreach (array_reverse($this->entries) as $entry) {
            $start = self::startFor($date, $entry);
            if ($entry->effectiveAt <= $start) {
                return $start;
            }
        }

        return self::startFor($date, $this->entries[0] ?? throw new DayResolutionException('no_calendar'));
    }

    /** First instant after a business date (UTC). */
    public function endOfLocalDay(LocalDate $date): DateTimeImmutable
    {
        return $this->startOfLocalDay($date->addDays(1));
    }

    private static function startFor(LocalDate $date, CalendarEntry $entry): DateTimeImmutable
    {
        $minutes = $entry->dayStartOffsetMinutes;
        $wall = sprintf('%s %02d:%02d:00', $date->toString(), intdiv($minutes, 60), $minutes % 60);

        return self::firstInstantOfWallTime($wall, $entry->zone);
    }

    /**
     * Earliest instant whose wall clock in $zone reads $wall; inside a DST gap, the transition.
     * PHP's own parsing picks the earlier or later repeat depending on the zone, so this resolves
     * transitions explicitly.
     */
    private static function firstInstantOfWallTime(string $wall, DateTimeZone $zone): DateTimeImmutable
    {
        $naive = (new DateTimeImmutable($wall, new DateTimeZone('UTC')))->getTimestamp();
        $transitions = $zone->getTransitions($naive - 2 * 86400, $naive + 2 * 86400);
        if ($transitions === []) {
            throw new InvalidArgumentException("No transition data for {$zone->getName()}");
        }

        // Intervals of constant offset: [start, nextStart).
        $intervals = [];
        foreach ($transitions as $i => $t) {
            $intervals[] = [
                'start' => $i === 0 ? PHP_INT_MIN : $t['ts'],
                'end' => isset($transitions[$i + 1]) ? $transitions[$i + 1]['ts'] : PHP_INT_MAX,
                'offset' => $t['offset'],
            ];
        }

        $candidates = [];
        foreach ($intervals as $interval) {
            $instant = $naive - $interval['offset'];
            if ($instant >= $interval['start'] && $instant < $interval['end']) {
                $candidates[] = $instant;
            }
        }

        if ($candidates === []) {
            // Gap: the wall time is skipped. Use the transition whose skipped range contains it.
            foreach ($intervals as $i => $interval) {
                $next = $intervals[$i + 1] ?? null;
                if ($next === null) {
                    break;
                }
                $boundary = $interval['end'];
                if ($boundary + $interval['offset'] <= $naive && $naive < $boundary + $next['offset']) {
                    $candidates[] = $boundary;
                }
            }
        }

        if ($candidates === []) {
            throw new InvalidArgumentException("Cannot resolve wall time {$wall} in {$zone->getName()}");
        }

        return (new DateTimeImmutable('@'.min($candidates)))->setTimezone(new DateTimeZone('UTC'));
    }
}
