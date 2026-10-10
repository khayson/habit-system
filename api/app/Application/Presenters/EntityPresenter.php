<?php

namespace App\Application\Presenters;

use App\Application\Calendar\UserCalendar;
use App\Application\Habits\HabitRepository;
use App\Domain\Clock;
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
        private Clock $clock,
    ) {}

    /** How many recent calendar entries the user entity carries (D1). */
    public const int CALENDAR_HISTORY_LIMIT = 10;

    /** @return array<string, mixed> */
    public function user(stdClass $user): array
    {
        $level = $this->xp->level((int) $user->xp);
        $inForce = UserCalendar::timeline((string) $user->id)->entryAt($this->clock->now());
        $recent = DB::table('user_timezone_history')->where('user_id', $user->id)
            ->orderByDesc('effective_at')->limit(self::CALENDAR_HISTORY_LIMIT)
            ->get(['timezone', 'day_start_offset_minutes', 'effective_at'])->reverse()->values();

        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            // The calendar in force now: what clients before 3.2 read as "the" zone (invariant 13).
            'timezone' => $inForce->timezone,
            'timezone_mode' => $user->timezone_mode,
            'day_start_offset_minutes' => $inForce->dayStartOffsetMinutes,
            // ASSUMPTION(A26): the recent entries, oldest first, including one pending (not yet
            // effective) change, so 3.2 clients can build a multi-entry timeline.
            'calendar_history' => $recent->map(fn (stdClass $row) => [
                'timezone' => $row->timezone,
                'day_start_offset_minutes' => (int) $row->day_start_offset_minutes,
                'effective_at' => UtcTime::format(WireTime::parse((string) $row->effective_at)),
            ])->all(),
            'version' => (int) ($user->version ?? 1),
            'auto_freeze' => (bool) $user->auto_freeze,
            // A9: level fields are server-computed; the client never evaluates the formula.
            'xp' => $level->xp,
            'level' => $level->level,
            'progress_into_level' => $level->progressIntoLevel,
            'next_level_threshold' => $level->nextLevelThreshold,
            'freeze_balance' => (int) $user->freeze_balance,
            'created_at' => UtcTime::format(WireTime::parse((string) $user->created_at)),
            // A20: typed or picked labels (never GPS), and a counter of photo changes. The
            // avatar's storage key and hash are never exposed.
            'city' => $user->city,
            'country_code' => $user->country_code,
            'avatar_version' => (int) $user->avatar_version,
            'has_avatar' => $user->avatar_key !== null,
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

    /**
     * A32 habit_progress: the streak cache row. Its version is the cache's version.
     *
     * @return array<string, mixed>
     */
    public function habitProgress(stdClass $cache): array
    {
        return [
            'habit_id' => $cache->habit_id,
            'current' => (int) $cache->current,
            'longest' => (int) $cache->longest,
            'unit' => $cache->unit,
            'computed_through' => $cache->computed_through,
        ];
    }

    /**
     * Phase 3.2b reminder: a clock time and ISO days, never a UTC instant. Tombstones keep
     * their fields with deleted_at set.
     *
     * @return array<string, mixed>
     */
    public function reminder(stdClass $row): array
    {
        return [
            'id' => $row->id,
            'habit_id' => $row->habit_id,
            'local_time' => substr((string) $row->local_time, 0, 5),
            'days_of_week' => array_map(intval(...), (array) HabitRepository::json($row->days_of_week)),
            'timezone_mode' => $row->timezone_mode,
            'timezone' => $row->timezone,
            'enabled' => (bool) $row->enabled,
            'version' => (int) $row->version,
            'deleted_at' => $row->deleted_at === null ? null : UtcTime::format(WireTime::parse((string) $row->deleted_at)),
        ];
    }

    /**
     * A32 period_evaluation: one closed period's result. Its version is the revision.
     *
     * @return array<string, mixed>
     */
    public function periodEvaluation(stdClass $row): array
    {
        return [
            'id' => $row->id,
            'habit_id' => $row->habit_id,
            'period_key' => $row->period_key,
            'start_date' => $row->start_date,
            'end_date' => $row->end_date,
            'completed' => (bool) $row->completed,
            'protected' => (bool) $row->protected,
            'definition_version' => (int) $row->definition_version,
            'timezone' => $row->timezone,
            'revision' => (int) $row->revision,
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
