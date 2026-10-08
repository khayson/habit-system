<?php

namespace App\Application\Periods;

use App\Application\Calendar\UserCalendar;
use App\Application\Habits\HabitRepository;
use App\Application\Journal\ChangeJournal;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Calendar\LocalDate;
use App\Domain\Calendar\TimezoneTimeline;
use App\Domain\Clock;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\LogState;
use App\Domain\Period\PeriodEngine;
use App\Domain\Period\PeriodEvaluation;
use App\Domain\Period\PeriodKind;
use App\Domain\Period\PeriodStatus;
use App\Domain\Streak\StreakCalculator;
use App\Support\UtcTime;
use Closure;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use stdClass;

/**
 * Closes periods and keeps the streak cache (A10, A32). The single writer of
 * `period_evaluations` and `habit_streak_cache`; every change is journaled in the same
 * transaction (invariant 6) as a read-only derived entity:
 * - `period_evaluation` (version = revision) when a closed daily period is first evaluated or
 *   its result changes (a late offline log);
 * - `habit_progress` (version = the cache's version) when current, longest, unit or
 *   computed_through change.
 *
 * Idempotent: UNIQUE(habit_id, period_key) + revision; an unchanged input writes and journals
 * nothing. Every write happens under the user-row lock (A1). Daily periods only for now (weekly
 * closes in Phase 4); `protected` stays false until freezes exist (Phase 5).
 */
final readonly class PeriodCloser
{
    public function __construct(
        private HabitRepository $habits,
        private HabitTypeRegistry $types,
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    /**
     * The job entry point: one transaction, user lock first. A crash anywhere rolls the whole
     * run back; the next run redoes it. Returns how many entities changed.
     *
     * @param  (Closure(string): void)|null  $afterHabit  test seam, called after each habit
     */
    public function closeUser(string $userId, ?Closure $afterHabit = null): int
    {
        return DB::transaction(function () use ($userId, $afterHabit): int {
            $this->journal->lockUser($userId);
            $timeline = UserCalendar::timeline($userId);
            $changed = $this->journalCalendarInForce($userId);
            $habits = DB::table('habits')->where('user_id', $userId)->orderBy('id')->get();
            foreach ($habits as $habit) {
                $changed += $this->refreshHabit($userId, $habit, $timeline);
                $afterHabit?->__invoke((string) $habit->id);
            }

            return $changed;
        });
    }

    /** Lazy path (A10): before serving streak or heatmap reads, only when something is stale. */
    public function closeUserIfStale(string $userId): int
    {
        return $this->isStale($userId) ? $this->closeUser($userId) : 0;
    }

    /**
     * Stale when a habit has no cache row, a dirty mark, or a watermark before the user's local
     * yesterday, or when the calendar in force differs from the last journaled user entity.
     */
    public function isStale(string $userId): bool
    {
        $yesterday = UserCalendar::timeline($userId)->localDateAt($this->clock->now())->addDays(-1)->toString();
        $habitStale = DB::table('habits')
            ->leftJoin('habit_streak_cache', 'habit_streak_cache.habit_id', '=', 'habits.id')
            ->where('habits.user_id', $userId)
            ->where(fn ($q) => $q->whereNull('habit_streak_cache.habit_id')
                ->orWhereNotNull('habit_streak_cache.dirty_from')
                ->orWhereNull('habit_streak_cache.computed_through')
                ->orWhere('habit_streak_cache.computed_through', '<', $yesterday))
            ->exists();

        return $habitStale || $this->calendarChangedSinceJournal($userId);
    }

    /**
     * Re-evaluates one habit inside a transaction that already holds the user lock (the job, or a
     * log mutation touching a closed period). Returns how many entities changed.
     */
    public function refreshHabit(string $userId, stdClass $habit, TimezoneTimeline $timeline): int
    {
        $today = $timeline->localDateAt($this->clock->now());
        $schedule = $this->habits->schedule($habit);
        $first = LocalDate::fromString((string) $habit->start_local_date);
        $type = $this->types->get((string) $habit->type);
        $logs = [];
        foreach (DB::table('habit_logs')->where('habit_id', $habit->id)->whereNull('deleted_at')->get(['log_date', 'value', 'detail']) as $log) {
            $logs[(string) $log->log_date] = new LogState($type->fromStorage((string) $log->value), HabitRepository::json($log->detail));
        }

        $engine = new PeriodEngine($this->types);
        $periods = $first->isAfter($today) ? [] : $engine->periods($schedule, $first, $today, $timeline);
        $evaluations = $engine->evaluate($periods, $logs, $today);

        // H2: one query for the habit's stored evaluations; unchanged days cost nothing more.
        $stored = DB::table('period_evaluations')->where('habit_id', $habit->id)->get()->keyBy('period_key')->all();
        $changed = 0;
        foreach ($evaluations as $evaluation) {
            if ($evaluation->closed && $evaluation->period->kind === PeriodKind::Day) {
                $changed += $this->storeEvaluation($userId, (string) $habit->id, $evaluation, $engine, $timeline, $stored[$evaluation->period->key] ?? null);
            }
        }

        $streak = (new StreakCalculator)->calculate($evaluations);

        return $changed + $this->storeProgress($userId, (string) $habit->id, $streak->current, $streak->longest, $streak->unit, $today->addDays(-1));
    }

    private function storeEvaluation(string $userId, string $habitId, PeriodEvaluation $evaluation, PeriodEngine $engine, TimezoneTimeline $timeline, ?stdClass $existing): int
    {
        $period = $evaluation->period;
        $result = [
            'definition_version' => $period->definition->version,
            'start_date' => $period->startDate->toString(),
            'end_date' => $period->endDate->toString(),
            'completed' => $evaluation->status === PeriodStatus::Complete,
            'protected' => $evaluation->status === PeriodStatus::Protected,
        ];
        // A closed day's bounds never change after it began (A26), so the result alone decides.
        if ($existing !== null && self::sameResult($existing, $result)) {
            return 0;
        }
        [$startsAt, $endsAt] = $engine->bounds($period, $timeline);
        $values = [
            ...$result,
            'timezone' => $timeline->entryAt($startsAt)->timezone,
            'starts_at' => UtcTime::format($startsAt),
            'ends_at' => UtcTime::format($endsAt),
        ];
        $now = UtcTime::format($this->clock->now());

        if ($existing === null) {
            $id = (string) Str::uuid7();
            DB::table('period_evaluations')->insert([
                'id' => $id, 'user_id' => $userId, 'habit_id' => $habitId, 'period_key' => $period->key,
                'revision' => 1, 'created_at' => $now, 'updated_at' => $now, ...$values,
            ]);
            $revision = 1;
        } else {
            $id = (string) $existing->id;
            $revision = (int) $existing->revision + 1;
            DB::table('period_evaluations')->where('id', $id)->update([
                'revision' => $revision, 'updated_at' => $now, ...$values,
            ]);
        }

        // The payload comes from the values just written; no read-back (H2).
        $row = (object) ['id' => $id, 'habit_id' => $habitId, 'period_key' => $period->key, 'revision' => $revision, ...$values];
        $this->journal->append($userId, 'period_evaluation', $id, 'upsert', $revision, $this->presenter->periodEvaluation($row));

        return 1;
    }

    private function storeProgress(string $userId, string $habitId, int $current, int $longest, string $unit, LocalDate $computedThrough): int
    {
        $cache = DB::table('habit_streak_cache')->where('habit_id', $habitId)->lockForUpdate()->first();
        $now = UtcTime::format($this->clock->now());
        $through = $computedThrough->toString();
        $unchanged = $cache !== null
            && (int) $cache->current === $current
            && (int) $cache->longest === $longest
            && (string) $cache->unit === $unit
            && (string) $cache->computed_through === $through;

        if ($unchanged) {
            if ($cache->dirty_from !== null) {
                DB::table('habit_streak_cache')->where('habit_id', $habitId)->update(['dirty_from' => null, 'updated_at' => $now]);
            }

            return 0;
        }

        $version = $cache === null ? 1 : (int) $cache->version + 1;
        DB::table('habit_streak_cache')->upsert([[
            'habit_id' => $habitId, 'current' => $current, 'longest' => $longest, 'unit' => $unit,
            'computed_through' => $through, 'dirty_from' => null, 'version' => $version, 'updated_at' => $now,
        ]], ['habit_id']);
        $row = (object) ['habit_id' => $habitId, 'current' => $current, 'longest' => $longest, 'unit' => $unit, 'computed_through' => $through];
        $this->journal->append($userId, 'habit_progress', $habitId, 'upsert', $version, $this->presenter->habitProgress($row));

        return 1;
    }

    /**
     * D1: a pending calendar change becomes the calendar in force at its boundary without any
     * mutation. The user entity says which calendar is in force, so it is journaled again then.
     */
    private function journalCalendarInForce(string $userId): int
    {
        if (! $this->calendarChangedSinceJournal($userId)) {
            return 0;
        }
        $user = DB::table('users')->where('id', $userId)->first() ?? (object) [];
        $version = (int) $user->version + 1;
        $inForce = UserCalendar::timeline($userId)->entryAt($this->clock->now());
        DB::table('users')->where('id', $userId)->update([
            'version' => $version,
            'timezone' => $inForce->timezone,
            'updated_at' => UtcTime::format($this->clock->now()),
        ]);
        $row = DB::table('users')->where('id', $userId)->first() ?? (object) [];
        $this->journal->append($userId, 'user', $userId, 'upsert', $version, $this->presenter->user($row));

        return 1;
    }

    private function calendarChangedSinceJournal(string $userId): bool
    {
        $last = DB::table('server_changes')->where('user_id', $userId)->where('entity_type', 'user')->orderByDesc('seq')->value('payload');
        $payload = HabitRepository::json($last);
        $inForce = UserCalendar::timeline($userId)->entryAt($this->clock->now());

        return $payload !== []
            && (($payload['timezone'] ?? null) !== $inForce->timezone
                || (int) ($payload['day_start_offset_minutes'] ?? 0) !== $inForce->dayStartOffsetMinutes);
    }

    /** @param array<string, mixed> $result */
    private static function sameResult(stdClass $existing, array $result): bool
    {
        return (int) $existing->definition_version === $result['definition_version']
            && (string) $existing->start_date === $result['start_date']
            && (string) $existing->end_date === $result['end_date']
            && (bool) $existing->completed === $result['completed']
            && (bool) $existing->protected === $result['protected'];
    }
}
