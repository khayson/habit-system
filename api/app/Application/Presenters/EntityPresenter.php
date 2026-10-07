<?php

namespace App\Application\Presenters;

use App\Application\Habits\HabitRepository;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Reward\XpRules;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Support\Facades\DB;
use stdClass;

/**
 * Wire shapes for the sync entities. Used by journal payloads, conflict `current` objects and
 * bootstrap pages, so every path describes an entity the same way. Values use wire forms
 * (invariant 10): quantities as decimal strings, durations as whole seconds.
 */
final readonly class EntityPresenter
{
    public function __construct(
        private HabitTypeRegistry $types,
        private HabitRepository $habits,
        private XpRules $xp,
    ) {}

    /** @return array<string, mixed> */
    public function user(stdClass $user): array
    {
        $level = $this->xp->level((int) $user->xp);
        $calendar = DB::table('user_timezone_history')->where('user_id', $user->id)->orderByDesc('effective_at')->first();

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'timezone' => $user->timezone,
            'timezone_mode' => $user->timezone_mode,
            'day_start_offset_minutes' => (int) ($calendar->day_start_offset_minutes ?? 0),
            'auto_freeze' => (bool) $user->auto_freeze,
            // A9: level fields are server-computed; the client never evaluates the formula.
            'xp' => $level->xp,
            'level' => $level->level,
            'progress_into_level' => $level->progressIntoLevel,
            'next_level_threshold' => $level->nextLevelThreshold,
            'freeze_balance' => (int) $user->freeze_balance,
            'created_at' => UtcTime::format(WireTime::parse((string) $user->created_at)),
        ];
    }

    /** @return array<string, mixed> */
    public function habit(stdClass $habit): array
    {
        $type = $this->types->get((string) $habit->type);

        return [
            'id' => $habit->id,
            'name' => $habit->name,
            'type' => $habit->type,
            'unit' => $habit->unit,
            'category' => $habit->category,
            'target_value' => $type->formatValue($type->fromStorage((string) $habit->target_value)),
            'frequency_type' => $habit->frequency_type,
            'frequency_config' => (object) HabitRepository::json($habit->frequency_config),
            'start_local_date' => $habit->start_local_date,
            'archived_at' => $habit->archived_at === null ? null : UtcTime::format(WireTime::parse((string) $habit->archived_at)),
            'version' => (int) $habit->version,
            'definition_version' => (int) $habit->definition_version,
            'definitions' => array_map(fn (stdClass $row) => [
                'version' => (int) $row->version,
                'effective_date' => $row->effective_date,
                'type' => $row->type,
                'target_value' => $type->formatValue($type->fromStorage((string) $row->target_value)),
                'unit' => $row->unit,
                'category' => $row->category,
                'frequency_type' => $row->frequency_type,
                'frequency_config' => (object) HabitRepository::json($row->frequency_config),
                'config' => (object) HabitRepository::json($row->config),
            ], $this->habits->definitionRows((string) $habit->id)),
            'active_ranges' => array_map(fn (stdClass $row) => [
                'starts_on' => $row->starts_on,
                'ends_before' => $row->ends_before,
            ], $this->habits->rangeRows((string) $habit->id)),
        ];
    }

    /** @return array<string, mixed> */
    public function log(stdClass $log, string $typeKey): array
    {
        $type = $this->types->get($typeKey);

        return [
            'id' => $log->id,
            'habit_id' => $log->habit_id,
            'log_date' => $log->log_date,
            'value' => $type->formatValue($type->fromStorage((string) $log->value)),
            'detail' => (object) HabitRepository::json($log->detail),
            'occurred_at' => WireTime::precise(WireTime::parse((string) $log->occurred_at)),
            'completed_at' => $log->completed_at === null ? null : WireTime::precise(WireTime::parse((string) $log->completed_at)),
            'resolved_timezone' => $log->resolved_timezone,
            'day_start_offset_minutes' => (int) $log->day_start_offset_minutes,
            'definition_version' => (int) $log->definition_version,
            'version' => (int) $log->version,
            'deleted_at' => $log->deleted_at === null ? null : UtcTime::format(WireTime::parse((string) $log->deleted_at)),
        ];
    }
}
