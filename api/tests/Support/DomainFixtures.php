<?php

namespace Tests\Support;

use App\Domain\Calendar\CalendarEntry;
use App\Domain\Calendar\LocalDate;
use App\Domain\Calendar\TimezoneTimeline;
use App\Domain\Habit\ActiveRange;
use App\Domain\Habit\DefinitionVersion;
use App\Domain\Habit\Frequency;
use App\Domain\Habit\HabitSchedule;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\LogState;
use DateTimeImmutable;
use DateTimeZone;

/** Builds domain objects from contract-fixture seeds (contract-fixtures/README.md). */
final class DomainFixtures
{
    /** @return array<string, mixed> */
    public static function load(string $name): array
    {
        $json = file_get_contents(dirname(__DIR__, 3)."/contract-fixtures/domain/{$name}.json");

        return json_decode((string) $json, true, flags: JSON_THROW_ON_ERROR);
    }

    public static function instant(string $iso): DateTimeImmutable
    {
        return (new DateTimeImmutable($iso))->setTimezone(new DateTimeZone('UTC'));
    }

    /** @param list<array{effective_at: string, timezone: string, day_start_offset_minutes: int}> $rows */
    public static function timeline(array $rows): TimezoneTimeline
    {
        return new TimezoneTimeline(array_map(
            fn (array $row) => new CalendarEntry(self::instant($row['effective_at']), $row['timezone'], $row['day_start_offset_minutes']),
            $rows,
        ));
    }

    /** @param array<string, mixed> $habit */
    public static function schedule(array $habit, HabitTypeRegistry $types): HabitSchedule
    {
        $versions = array_map(fn (array $d) => new DefinitionVersion(
            $d['version'],
            LocalDate::fromString($d['effective_date']),
            $d['type'],
            $types->get($d['type'])->parseTarget($d['target']),
            $d['unit'],
            $habit['category'],
            Frequency::fromArray($d['frequency_type'], $d['frequency_config']),
        ), $habit['definitions']);

        $ranges = array_map(fn (array $r) => new ActiveRange(
            LocalDate::fromString($r['starts_on']),
            $r['ends_before'] === null ? null : LocalDate::fromString($r['ends_before']),
        ), $habit['active_ranges']);

        return new HabitSchedule($habit['id'], $versions, $ranges);
    }

    /**
     * @param  array<string, mixed>  $habit
     * @return array<string, LogState>
     */
    public static function logValues(array $habit, HabitTypeRegistry $types): array
    {
        $type = $types->get($habit['definitions'][0]['type']);

        return array_map(fn (mixed $wire) => new LogState($type->parseValue($wire)), $habit['logs']);
    }

    /** A daily definition for type-level tests. */
    public static function definition(string $type, mixed $target, HabitTypeRegistry $types): DefinitionVersion
    {
        return new DefinitionVersion(1, LocalDate::fromString('2026-05-01'), $type, $types->get($type)->parseTarget($target), null, 'health', Frequency::daily());
    }

    /**
     * Fixture cases keyed by name, for Pest datasets.
     *
     * @param  list<array<string, mixed>>  $cases
     * @return array<string, array{array<string, mixed>}>
     */
    public static function named(array $cases): array
    {
        $out = [];
        foreach ($cases as $case) {
            $out[(string) $case['name']] = [$case];
        }

        return $out;
    }
}
