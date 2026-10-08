<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Habits\HabitRepository;
use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\DependencyPending;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Calendar\CalendarEntry;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use LogicException;
use stdClass;

/**
 * Phase 3.2b: reminder.create / reminder.update / reminder.delete (spec 06 "reminders"). Each
 * write is owner-scoped, version-checked and journaled in the applier's transaction
 * (invariant 6); a delete is a tombstone.
 *
 * ASSUMPTION(A3.2b-reminder-payload): explicit fields only. local_time is "HH:MM" (a clock time,
 * never UTC); days_of_week are unique ISO days 1..7, stored sorted; timezone_mode is habit_zone
 * or device_zone with an optional IANA timezone; enabled defaults to true. A reminder's habit
 * is fixed at create.
 * ASSUMPTION(A3.2b-recreate): a deleted reminder is not revived; a new reminder takes a new id.
 */
final readonly class ReminderWrites
{
    public function __construct(
        private HabitRepository $habits,
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    public function create(MutationContext $ctx): HandlerResult
    {
        $m = $ctx->mutation;
        $habitId = $m->payload['habit_id'] ?? null;
        if (! is_string($habitId) || Validator::make(['habit_id' => $habitId], ['habit_id' => 'uuid'])->fails()) {
            throw ValidationException::withMessages(['habit_id' => ['A valid habit_id is required.']]);
        }
        $fields = $this->fields($m->payload);
        // A missing or foreign habit is the same answer: the habit may still be on its way.
        $habit = $this->habits->findOwned($ctx->userId, strtolower($habitId)) ?? throw new DependencyPending;

        $existing = DB::table('reminders')->where('id', $m->entityId)->first();
        if ($existing !== null) {
            if ($existing->user_id !== $ctx->userId) {
                throw new ApiException(404, 'not_found', 'Not found.');
            }
            if ($existing->deleted_at !== null) {
                throw ApiException::resourceDeleted('reminder', $m->entityId, (int) $existing->version);
            }
            throw ApiException::versionConflict($m->entityId, 0, (int) $existing->version, $this->presenter->reminder($existing));
        }

        $now = UtcTime::format($this->clock->now());
        DB::table('reminders')->insert([
            'id' => $m->entityId,
            'user_id' => $ctx->userId,
            'habit_id' => $habit->id,
            ...$fields,
            'version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return $this->journaled($ctx->userId, $m->entityId, 'upsert');
    }

    public function update(MutationContext $ctx): HandlerResult
    {
        $m = $ctx->mutation;
        $fields = $this->fields($m->payload);
        $row = $this->current($ctx);
        $version = (int) $row->version;

        $unchanged = substr((string) $row->local_time, 0, 5) === $fields['local_time']
            && HabitRepository::json($row->days_of_week) === json_decode($fields['days_of_week'], true)
            && $row->timezone_mode === $fields['timezone_mode']
            && $row->timezone === $fields['timezone']
            && (bool) $row->enabled === $fields['enabled'];
        if ($unchanged) {
            // Identical desired state: acknowledged without a new version (spec 07).
            return new HandlerResult('reminder', $m->entityId, $version);
        }

        DB::table('reminders')->where('id', $m->entityId)->where('user_id', $ctx->userId)->update([
            ...$fields,
            'version' => $version + 1,
            'updated_at' => UtcTime::format($this->clock->now()),
        ]);

        return $this->journaled($ctx->userId, $m->entityId, 'upsert');
    }

    public function delete(MutationContext $ctx): HandlerResult
    {
        $m = $ctx->mutation;
        $row = $this->current($ctx);
        $now = UtcTime::format($this->clock->now());
        DB::table('reminders')->where('id', $m->entityId)->where('user_id', $ctx->userId)->update([
            'version' => (int) $row->version + 1,
            'deleted_at' => $now,
            'updated_at' => $now,
        ]);

        return $this->journaled($ctx->userId, $m->entityId, 'delete');
    }

    /** The live, owned reminder at base_version; every other case is answered without a write. */
    private function current(MutationContext $ctx): stdClass
    {
        $m = $ctx->mutation;
        if ($m->baseVersion === null) {
            throw ValidationException::withMessages(['base_version' => ['base_version is required.']]);
        }
        // Another owner's id is answered exactly like a missing one (invariant 2).
        $row = DB::table('reminders')->where('id', $m->entityId)->where('user_id', $ctx->userId)->lockForUpdate()->first()
            ?? throw new ApiException(404, 'not_found', 'Not found.');
        if ($row->deleted_at !== null) {
            throw ApiException::resourceDeleted('reminder', $m->entityId, (int) $row->version);
        }
        if ($m->baseVersion !== (int) $row->version) {
            throw ApiException::versionConflict($m->entityId, $m->baseVersion, (int) $row->version, $this->presenter->reminder($row));
        }

        return $row;
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array{local_time: string, days_of_week: string, timezone_mode: string, timezone: ?string, enabled: bool}
     */
    private function fields(array $payload): array
    {
        $p = Validator::make($payload, [
            'local_time' => ['required', 'string', 'regex:/^([01]\d|2[0-3]):[0-5]\d$/'],
            'days_of_week' => ['required', 'array', 'list', 'min:1', 'max:7'],
            'days_of_week.*' => ['integer', 'between:1,7', 'distinct'],
            'timezone_mode' => ['required', Rule::in(['habit_zone', 'device_zone'])],
            'timezone' => ['nullable', 'string', 'max:64'],
            'enabled' => ['sometimes', 'boolean'],
        ])->validate();
        $zone = $p['timezone'] ?? null;
        if (is_string($zone) && ! CalendarEntry::isIanaZone($zone)) {
            throw ValidationException::withMessages(['timezone' => ['Choose a time zone from the list.']]);
        }
        $days = array_map(intval(...), (array) $p['days_of_week']);
        sort($days);

        return [
            'local_time' => (string) $p['local_time'],
            'days_of_week' => json_encode($days, JSON_THROW_ON_ERROR),
            'timezone_mode' => (string) $p['timezone_mode'],
            'timezone' => is_string($zone) ? $zone : null,
            'enabled' => (bool) ($p['enabled'] ?? true),
        ];
    }

    /** @param 'upsert'|'delete' $operation */
    private function journaled(string $userId, string $id, string $operation): HandlerResult
    {
        $row = DB::table('reminders')->where('id', $id)->where('user_id', $userId)->first()
            ?? throw new LogicException('Reminder vanished inside its own transaction.');
        $version = (int) $row->version;
        $this->journal->append($userId, 'reminder', $id, $operation, $version, $this->presenter->reminder($row));

        return new HandlerResult('reminder', $id, $version);
    }
}
