<?php

namespace App\Application\Habits;

use App\Domain\Calendar\LocalDate;
use App\Domain\Habit\ActiveRange;
use App\Domain\Habit\DefinitionVersion;
use App\Domain\Habit\Frequency;
use App\Domain\Habit\HabitSchedule;
use App\Domain\Habit\HabitTypeRegistry;
use Illuminate\Support\Facades\DB;
use stdClass;

/** Owner-scoped habit reads (invariant 2) and their mapping to domain objects. */
final readonly class HabitRepository
{
    public function __construct(private HabitTypeRegistry $types) {}

    /** The habit if, and only if, it belongs to the user. */
    public function findOwned(string $userId, string $habitId): ?stdClass
    {
        return DB::table('habits')->where('user_id', $userId)->where('id', $habitId)->first();
    }

    public function existsForAnyone(string $habitId): bool
    {
        return DB::table('habits')->where('id', $habitId)->exists();
    }

    /** @return list<stdClass> */
    public function definitionRows(string $habitId): array
    {
        return array_values(DB::table('habit_definition_versions')->where('habit_id', $habitId)->orderBy('version')->get()->all());
    }

    /** @return list<stdClass> */
    public function rangeRows(string $habitId): array
    {
        return array_values(DB::table('habit_active_ranges')->where('habit_id', $habitId)->orderBy('starts_on')->get()->all());
    }

    public function schedule(stdClass $habit): HabitSchedule
    {
        $type = $this->types->get((string) $habit->type);

        $versions = array_map(fn (stdClass $row) => new DefinitionVersion(
            (int) $row->version,
            LocalDate::fromString((string) $row->effective_date),
            (string) $row->type,
            $type->fromStorage((string) $row->target_value),
            $row->unit === null ? null : (string) $row->unit,
            (string) $row->category,
            Frequency::fromArray((string) $row->frequency_type, self::json($row->frequency_config)),
            self::json($row->config),
        ), $this->definitionRows((string) $habit->id));

        $ranges = array_map(fn (stdClass $row) => new ActiveRange(
            LocalDate::fromString((string) $row->starts_on),
            $row->ends_before === null ? null : LocalDate::fromString((string) $row->ends_before),
        ), $this->rangeRows((string) $habit->id));

        return new HabitSchedule((string) $habit->id, $versions, $ranges);
    }

    /** @return array<string, mixed> */
    public static function json(mixed $value): array
    {
        $decoded = is_string($value) ? json_decode($value, true) : $value;

        return is_array($decoded) ? $decoded : [];
    }
}
