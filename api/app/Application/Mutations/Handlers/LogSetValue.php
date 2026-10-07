<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Calendar\UserCalendar;
use App\Application\Habits\HabitRepository;
use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Calendar\DayResolver;
use App\Domain\Clock;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\LogState;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use LogicException;
use stdClass;

/**
 * log.set_value (A27 canonical; alias log.set_binary): absolute, version-checked edit of one
 * habit-day (spec 07). base_version is required; 0 means the log is absent; the tombstone's
 * version restores a deleted day (A29). The date comes from
 * occurred_at and the user's calendar history, never from receipt time (invariant 3).
 */
final readonly class LogSetValue
{
    public function __construct(
        private HabitTypeRegistry $types,
        private HabitRepository $habits,
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    public function handle(MutationContext $ctx, stdClass $habit): HandlerResult
    {
        $m = $ctx->mutation;
        Validator::make($m->payload, ['value' => ['present'], 'detail' => ['nullable', 'array']])->validate();
        if ($m->baseVersion === null) {
            throw ValidationException::withMessages(['base_version' => ['base_version is required; use 0 when the log is absent.']]);
        }

        $type = $this->types->get((string) $habit->type);
        $schedule = $this->habits->schedule($habit);
        $resolution = (new DayResolver(UserCalendar::timeline($ctx->userId), $this->clock))
            ->resolve($m->occurredAt, $m->capturedTimezone, $m->localDateHint);
        $date = $resolution->localDate;
        $definition = $schedule->versionOn($date);
        if ($definition === null || ! $schedule->isEligible($date)) {
            throw ValidationException::withMessages(['occurred_at' => ['The habit is not active on that date.']]);
        }

        $existing = DB::table('habit_logs')->where('habit_id', $habit->id)->where('log_date', $date->toString())->lockForUpdate()->first();
        // A29 restore: a tombstone is restored only by a client that has seen the delete, i.e. that
        // sends the tombstone's version. An edit queued before the delete still conflicts, so
        // nothing is silently resurrected (spec 07).
        $restoring = false;
        if ($existing !== null && $existing->deleted_at !== null) {
            if ($m->baseVersion !== (int) $existing->version) {
                throw ApiException::resourceDeleted('habit_log', (string) $existing->id, (int) $existing->version);
            }
            $restoring = true;
        }

        $current = $existing === null || $restoring
            ? LogState::empty()
            : new LogState($type->fromStorage((string) $existing->value), HabitRepository::json($existing->detail));
        $next = $type->apply('log.set_value', $current, $m->payload['value'], $definition);

        if ($existing !== null && ! $restoring && $next->equals($current)) {
            // Identical desired state: acknowledge without a new version (spec 07).
            return new HandlerResult('habit_log', (string) $existing->id, (int) $existing->version, $date->toString());
        }
        $currentVersion = $existing === null ? 0 : (int) $existing->version;
        if ($m->baseVersion !== $currentVersion) {
            throw ApiException::versionConflict(
                (string) ($existing->id ?? $m->entityId),
                $m->baseVersion,
                $currentVersion,
                $existing === null ? [] : $this->presenter->log($existing, (string) $habit->type),
            );
        }

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
        $row = DB::table('habit_logs')->where('id', $id)->first();
        $this->journal->append($ctx->userId, 'habit_log', $id, 'upsert', $currentVersion + 1, $this->presenter->log($row ?? throw new LogicException('Log vanished inside its own transaction.'), (string) $habit->type));

        return new HandlerResult('habit_log', $id, $currentVersion + 1, $date->toString());
    }
}
