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
use stdClass;

/**
 * log.increment {habit_id, delta, date_mode?, log_date?} (A35): an additive merge with no
 * base_version. The receipt applies it once, and the applier holds the user-row lock for the
 * whole mutation, so concurrent increments on one habit-day run one after another and none is
 * lost. The type validates and adds the delta (invariant 14); the day is resolved and written
 * exactly as log.set_value does.
 */
final readonly class LogIncrement
{
    public function __construct(
        private HabitTypeRegistry $types,
        private EntityPresenter $presenter,
        private LogDay $day,
    ) {}

    public function handle(MutationContext $ctx, stdClass $habit): HandlerResult
    {
        $m = $ctx->mutation;
        $p = Validator::make($m->payload, [
            'delta' => ['present'],
            'date_mode' => ['nullable', Rule::in(['normal', 'backdate'])],
            'log_date' => ['required_if:date_mode,backdate', 'nullable', 'date_format:Y-m-d'],
        ])->validate();

        $type = $this->types->get((string) $habit->type);
        [$resolution, $definition] = $this->day->resolve($ctx, $habit, $p);
        $date = $resolution->localDate;

        $existing = DB::table('habit_logs')->where('habit_id', $habit->id)->where('log_date', $date->toString())->lockForUpdate()->first();
        if ($existing !== null && $existing->deleted_at !== null) {
            // A deleted day is not revived by an increment that may predate the delete.
            throw ApiException::resourceDeleted('habit_log', (string) $existing->id, (int) $existing->version, $this->presenter->log($existing, (string) $habit->type));
        }
        $current = $existing === null
            ? LogState::empty()
            : new LogState($type->fromStorage((string) $existing->value), HabitRepository::json($existing->detail));
        $next = $type->apply('log.increment', $current, $p['delta'], $definition);

        return $this->day->write($ctx, $habit, $type, $definition, $resolution, $existing, false, $next, $existing === null ? 0 : (int) $existing->version);
    }
}
