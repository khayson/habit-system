<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Habits\HabitRepository;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\LogState;
use App\Exceptions\ApiException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
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
        private EntityPresenter $presenter,
        private LogDay $day,
    ) {}

    public function handle(MutationContext $ctx, stdClass $habit): HandlerResult
    {
        $m = $ctx->mutation;
        // ASSUMPTION(A3.1-backdate-payload): explicit backdate mirrors habit.create's
        // date_mode, with the claimed local date in log_date (the spec names the rule, not the
        // field). Without date_mode the date comes from occurred_at as always.
        $p = Validator::make($m->payload, [
            'value' => ['present'],
            'detail' => ['nullable', 'array'],
            'date_mode' => ['nullable', Rule::in(['normal', 'backdate'])],
            'log_date' => ['required_if:date_mode,backdate', 'nullable', 'date_format:Y-m-d'],
        ])->validate();
        if ($m->baseVersion === null) {
            throw ValidationException::withMessages(['base_version' => ['base_version is required; use 0 when the log is absent.']]);
        }

        $type = $this->types->get((string) $habit->type);
        [$resolution, $definition] = $this->day->resolve($ctx, $habit, $p);
        $date = $resolution->localDate;

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

        return $this->day->write($ctx, $habit, $type, $definition, $resolution, $existing, $restoring, $next, $currentVersion);
    }
}
