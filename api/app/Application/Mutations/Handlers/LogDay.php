<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Calendar\UserCalendar;
use App\Application\Habits\HabitRepository;
use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Periods\PeriodCloser;
use App\Application\Presenters\EntityPresenter;
use App\Application\Rewards\XpAwarder;
use App\Domain\Calendar\DayResolution;
use App\Domain\Calendar\DayResolver;
use App\Domain\Calendar\LocalDate;
use App\Domain\Clock;
use App\Domain\Habit\DefinitionVersion;
use App\Domain\Habit\HabitType;
use App\Domain\Habit\LogState;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use LogicException;
use stdClass;

/**
 * The habit-day steps log.set_value and log.increment share (A35): resolving the date from
 * occurred_at (or an explicit backdate) and the user's calendar history, and writing the new
 * state with its journal row, streak invalidation and derived refresh in the mutation's
 * transaction (invariant 6).
 */
final readonly class LogDay
{
    public function __construct(
        private HabitRepository $habits,
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private PeriodCloser $closer,
        private XpAwarder $xp,
        private Clock $clock,
    ) {}

    /**
     * The habit-day a log write lands on, and the definition governing it. Never receipt time,
     * never server "today" (invariant 3).
     *
     * @param  array<string, mixed>  $p  validated payload (date_mode, log_date)
     * @return array{DayResolution, DefinitionVersion}
     */
    public function resolve(MutationContext $ctx, stdClass $habit, array $p): array
    {
        $m = $ctx->mutation;
        $resolver = new DayResolver(UserCalendar::timeline($ctx->userId), $this->clock);
        $resolution = ($p['date_mode'] ?? 'normal') === 'backdate'
            // Spec 08: a separately validated local date, at most 30 days before the user's
            // local today at occurred_at and never after it; no invented timestamp.
            ? $resolver->resolveBackdate(LocalDate::fromString((string) $p['log_date']), $m->occurredAt)
            : $resolver->resolve($m->occurredAt, $m->capturedTimezone, $m->localDateHint);
        $schedule = $this->habits->schedule($habit);
        $definition = $schedule->versionOn($resolution->localDate);
        if ($definition === null || ! $schedule->isEligible($resolution->localDate)) {
            throw ValidationException::withMessages(['occurred_at' => ['The habit is not active on that date.']]);
        }

        return [$resolution, $definition];
    }

    /**
     * Writes the habit-day's new state at $currentVersion + 1, inserting the log when there is
     * none ($existing null) and clearing a tombstone when $restoring.
     */
    public function write(
        MutationContext $ctx,
        stdClass $habit,
        HabitType $type,
        DefinitionVersion $definition,
        DayResolution $resolution,
        ?stdClass $existing,
        bool $restoring,
        LogState $next,
        int $currentVersion,
    ): HandlerResult {
        $m = $ctx->mutation;
        $date = $resolution->localDate;
        $complete = $type->isComplete($next, $definition);
        $previousCompletedAt = $restoring ? null : $existing?->completed_at;
        $completedAt = match (true) {
            ! $complete => null,
            $previousCompletedAt !== null => (string) $previousCompletedAt,
            default => WireTime::forDatabase($m->occurredAt),
        };
        $occurredAt = $existing !== null && ! $restoring && WireTime::parse((string) $existing->occurred_at) > $m->occurredAt
            ? (string) $existing->occurred_at
            : WireTime::forDatabase($m->occurredAt);
        $now = UtcTime::format($this->clock->now());
        $values = [
            'value' => $type->toStorage($next->value),
            'detail' => json_encode((object) $next->detail, JSON_THROW_ON_ERROR),
            'occurred_at' => $occurredAt,
            'completed_at' => $completedAt,
            'resolved_timezone' => $resolution->entry->timezone,
            'day_start_offset_minutes' => $resolution->entry->dayStartOffsetMinutes,
            'definition_version' => $definition->version,
            'version' => $currentVersion + 1,
            'deleted_at' => null,
            'updated_at' => $now,
        ];

        if ($existing === null) {
            // Client ids are hints: never reuse an id that already exists anywhere.
            $id = DB::table('habit_logs')->where('id', $m->entityId)->exists() ? (string) Str::uuid7() : $m->entityId;
            DB::table('habit_logs')->insert([
                'id' => $id,
                'user_id' => $ctx->userId,
                'habit_id' => $habit->id,
                'log_date' => $date->toString(),
                'created_at' => $now,
                ...$values,
            ]);
        } else {
            $id = (string) $existing->id;
            DB::table('habit_logs')->where('id', $id)->update($values);
        }

        LogWrites::markStreakDirty((string) $habit->id, $date->toString(), $now);
        // A40: completed_at is set exactly while the day meets its target (above), so it says
        // whether the day was complete before this write.
        $wasComplete = $existing !== null && ! $restoring && $existing->deleted_at === null && $existing->completed_at !== null;
        $xpDelta = $this->xp->award($ctx->userId, (string) $habit->id, $date->toString(), $wasComplete, $complete, $m->mutationId);
        $row = DB::table('habit_logs')->where('id', $id)->first();
        $this->journal->append($ctx->userId, 'habit_log', $id, 'upsert', $currentVersion + 1, $this->presenter->log($row ?? throw new LogicException('Log vanished inside its own transaction.'), (string) $habit->type));
        // A10/A32: a late log re-evaluates its closed period, and any log can move the streak;
        // the derived entities are journaled in this same transaction (invariant 6).
        $this->closer->refreshHabit($ctx->userId, $habit, UserCalendar::timeline($ctx->userId));

        return new HandlerResult('habit_log', $id, $currentVersion + 1, $date->toString(), $xpDelta);
    }
}
