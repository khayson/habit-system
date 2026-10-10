<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Calendar\UserCalendar;
use App\Application\Habits\HabitRepository;
use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Calendar\DayResolver;
use App\Domain\Calendar\LocalDate;
use App\Domain\Clock;
use App\Domain\Habit\DefinitionVersion;
use App\Domain\Habit\Frequency;
use App\Domain\Habit\HabitArchived;
use App\Domain\Habit\HabitSchedule;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\InvalidHabitValue;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;
use LogicException;
use stdClass;

/**
 * A34: habit.update, habit.archive and habit.restore. Each is owner-scoped, checked against
 * habits.version, and journals ONE habit row in the applier's transaction (invariant 6). A
 * desired state equal to the current one is acknowledged with no version and no journal row.
 *
 * Dates come from the user's calendar at APPLY time (server clock), never from the client.
 */
final readonly class HabitWrites
{
    public function __construct(
        private HabitTypeRegistry $types,
        private HabitRepository $habits,
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    public function update(MutationContext $ctx): HandlerResult
    {
        $m = $ctx->mutation;
        $habit = $this->checked($ctx);
        $p = Validator::make($m->payload, [
            'name' => ['required', 'string', 'max:100'],
            'type' => ['nullable', 'string', 'max:24'],
            'target_value' => ['present'],
            'unit' => ['present', 'nullable', 'string', 'max:24'],
            'category' => ['required', Rule::in(DefinitionVersion::CATEGORIES)],
            'frequency_type' => ['required', 'string', 'max:24'],
            'frequency_config' => ['present', 'array'],
        ])->validate();
        if ($habit->archived_at !== null) {
            throw new HabitArchived((string) $habit->id);
        }
        $typeKey = (string) $habit->type;
        // A4: the type is immutable.
        if (isset($p['type']) && $p['type'] !== $typeKey) {
            throw new InvalidHabitValue('The type of a habit cannot change.');
        }
        $type = $this->types->get($typeKey);
        try {
            $target = $type->parseTarget($p['target_value']);
        } catch (InvalidHabitValue $e) {
            throw ValidationException::withMessages(['target_value' => [$e->getMessage()]]);
        }
        try {
            $unit = $this->types->normalizeUnit($typeKey, isset($p['unit']) ? (string) $p['unit'] : null);
        } catch (InvalidHabitValue $e) {
            throw ValidationException::withMessages(['unit' => [$e->getMessage()]]);
        }
        try {
            $frequency = Frequency::fromArray((string) $p['frequency_type'], (array) $p['frequency_config']);
        } catch (InvalidArgumentException $e) {
            throw ValidationException::withMessages(['frequency_config' => [$e->getMessage()]]);
        }
        $name = trim((string) $p['name']);
        $desired = ['target' => $target, 'unit' => $unit, 'category' => (string) $p['category'], 'frequency' => $frequency->toArray()];

        $today = $this->today($ctx);
        $schedule = $this->habits->schedule($habit);
        $latest = $schedule->latest();
        $inForce = $schedule->versionOn($today);
        $pending = $latest->effectiveDate->isAfter($today);
        $now = UtcTime::format($this->clock->now());

        $definitionChanged = false;
        if (self::fields($latest) !== $desired) {
            $definitionChanged = true;
            if ($pending && $inForce !== null && self::fields($inForce) === $desired) {
                // Back to the version in force: the pending change is withdrawn.
                DB::table('habit_definition_versions')->where('habit_id', $habit->id)->where('version', $latest->version)->delete();
            } elseif ($pending) {
                // Not in force yet: replaced in place. A first version that starts later keeps its
                // start date; a later one starts where the version in force allows.
                $effective = $inForce === null
                    ? $latest->effectiveDate
                    : HabitSchedule::nextEffectiveDate($today, $inForce->frequency, $frequency);
                DB::table('habit_definition_versions')->where('habit_id', $habit->id)->where('version', $latest->version)
                    ->update([...$this->definitionColumns($typeKey, $target, $unit, $desired['category'], $frequency), 'effective_date' => $effective->toString()]);
            } else {
                DB::table('habit_definition_versions')->insert([
                    'id' => (string) Str::uuid7(),
                    'habit_id' => $habit->id,
                    'version' => $latest->version + 1,
                    'effective_date' => HabitSchedule::nextEffectiveDate($today, $latest->frequency, $frequency)->toString(),
                    'type' => $typeKey,
                    ...$this->definitionColumns($typeKey, $target, $unit, $desired['category'], $frequency),
                    'config' => '{}',
                    'created_at' => $now,
                ]);
            }
        }
        if (! $definitionChanged && $name === $habit->name) {
            return new HandlerResult('habit', (string) $habit->id, (int) $habit->version);
        }

        // The habit's top-level fields stay the projection of the latest definition.
        $rows = $this->habits->definitionRows((string) $habit->id);
        $top = $rows[count($rows) - 1];

        return $this->journaled($habit, [
            'name' => $name,
            'target_value' => $top->target_value,
            'unit' => $top->unit,
            'category' => $top->category,
            'frequency_type' => $top->frequency_type,
            'frequency_config' => $top->frequency_config,
            'definition_version' => (int) $top->version,
        ], $now);
    }

    public function archive(MutationContext $ctx): HandlerResult
    {
        $habit = $this->checked($ctx);
        if ($habit->archived_at !== null) {
            return new HandlerResult('habit', (string) $habit->id, (int) $habit->version);
        }
        $tomorrow = $this->today($ctx)->addDays(1);
        $open = DB::table('habit_active_ranges')->where('habit_id', $habit->id)->whereNull('ends_before')->first();
        if ($open !== null) {
            if (LocalDate::fromString((string) $open->starts_on)->isBefore($tomorrow)) {
                // Today's check-ins stay valid: the range ends at the start of tomorrow.
                DB::table('habit_active_ranges')->where('id', $open->id)->update(['ends_before' => $tomorrow->toString()]);
            } else {
                // ASSUMPTION(A34-empty-range): a range that has not started yet (a restore earlier
                // today) would end where it starts; it is removed instead.
                DB::table('habit_active_ranges')->where('id', $open->id)->delete();
            }
        }
        $now = UtcTime::format($this->clock->now());

        return $this->journaled($habit, ['archived_at' => $now], $now);
    }

    public function restore(MutationContext $ctx): HandlerResult
    {
        $habit = $this->checked($ctx);
        if ($habit->archived_at === null) {
            return new HandlerResult('habit', (string) $habit->id, (int) $habit->version);
        }
        $today = $this->today($ctx);
        $previous = DB::table('habit_active_ranges')->where('habit_id', $habit->id)->orderByDesc('starts_on')->first();
        $start = $today;
        if ($previous !== null && $previous->ends_before !== null) {
            $end = LocalDate::fromString((string) $previous->ends_before);
            // No overlap: the new range starts no earlier than the previous one ended.
            $start = $end->isAfter($today) ? $end : $today;
        }
        $now = UtcTime::format($this->clock->now());
        DB::table('habit_active_ranges')->insert([
            'id' => (string) Str::uuid7(),
            'habit_id' => $habit->id,
            'starts_on' => $start->toString(),
            'ends_before' => null,
            'created_at' => $now,
        ]);

        return $this->journaled($habit, ['archived_at' => null], $now);
    }

    /** Owner and version checks shared by the three operations. */
    private function checked(MutationContext $ctx): stdClass
    {
        $m = $ctx->mutation;
        if ($m->baseVersion === null) {
            throw ValidationException::withMessages(['base_version' => ['base_version is required.']]);
        }
        // A missing or foreign habit is one answer (invariant 2).
        $habit = DB::table('habits')->where('user_id', $ctx->userId)->where('id', $m->entityId)->lockForUpdate()->first()
            ?? throw new ApiException(404, 'not_found', 'Not found.');
        if ($m->baseVersion !== (int) $habit->version) {
            throw ApiException::versionConflict((string) $habit->id, $m->baseVersion, (int) $habit->version, $this->presenter->habit($habit));
        }

        return $habit;
    }

    private function today(MutationContext $ctx): LocalDate
    {
        return (new DayResolver(UserCalendar::timeline($ctx->userId), $this->clock))->today();
    }

    /**
     * @param  array<string, mixed>  $values
     */
    private function journaled(stdClass $habit, array $values, string $now): HandlerResult
    {
        $version = (int) $habit->version + 1;
        DB::table('habits')->where('id', $habit->id)->update([...$values, 'version' => $version, 'updated_at' => $now]);
        $row = DB::table('habits')->where('id', $habit->id)->first() ?? throw new LogicException('Habit vanished inside its own transaction.');
        $this->journal->append((string) $habit->user_id, 'habit', (string) $habit->id, 'upsert', $version, $this->presenter->habit($row));

        return new HandlerResult('habit', (string) $habit->id, $version);
    }

    /** @return array{target: int, unit: ?string, category: string, frequency: array<string, mixed>} */
    private static function fields(DefinitionVersion $v): array
    {
        return ['target' => $v->target, 'unit' => $v->unit, 'category' => $v->category, 'frequency' => $v->frequency->toArray()];
    }

    /** @return array<string, mixed> */
    private function definitionColumns(string $typeKey, int $target, ?string $unit, string $category, Frequency $frequency): array
    {
        return [
            'target_value' => $this->types->get($typeKey)->toStorage($target),
            'unit' => $unit,
            'category' => $category,
            'frequency_type' => $frequency->type->value,
            // S3: the canonical form, never the raw client object.
            'frequency_config' => json_encode((object) $frequency->toArray(), JSON_THROW_ON_ERROR),
        ];
    }
}
