<?php

namespace App\Application\Mutations\Handlers;

use Illuminate\Support\Facades\DB;
use stdClass;

/** Shared side effects of a log change, inside the mutation transaction. */
final class LogWrites
{
    /** Invalidate the streak cache from the changed date onward (spec 02: transactional). */
    public static function markStreakDirty(string $habitId, string $logDate, string $now): void
    {
        DB::statement(
            'INSERT INTO habit_streak_cache (habit_id, dirty_from, updated_at) VALUES (?, ?, ?)
             ON CONFLICT (habit_id) DO UPDATE SET
               dirty_from = LEAST(COALESCE(habit_streak_cache.dirty_from, EXCLUDED.dirty_from), EXCLUDED.dirty_from),
               version = habit_streak_cache.version + 1,
               updated_at = EXCLUDED.updated_at',
            [$habitId, $logDate, $now],
        );
    }

    public static function find(string $userId, string $logId): ?stdClass
    {
        return DB::table('habit_logs')->where('user_id', $userId)->where('id', $logId)->lockForUpdate()->first();
    }
}
