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
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\UnknownHabitType;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;
use LogicException;

/**
 * habit.create (spec 05, 07). The id is client-supplied for offline creation. Creates the
 * habit, definition version 1 and the first active range, and journals the habit.
 */
final readonly class HabitCreate
{
    public function __construct(
        private HabitTypeRegistry $types,
        private HabitRepository $habits,
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    public function handle(MutationContext $ctx): HandlerResult
    {
        $p = Validator::make($ctx->mutation->payload, [
            'name' => ['required', 'string', 'max:100'],
            'type' => ['required', 'string', 'max:24'],
            'target_value' => ['present'],
            'unit' => ['nullable', 'string', 'max:24'],
            'category' => ['required', Rule::in(DefinitionVersion::CATEGORIES)],
            'frequency_type' => ['required', 'string', 'max:24'],
            'frequency_config' => ['present', 'array'],
            'start_local_date' => ['required', 'date_format:Y-m-d'],
            'date_mode' => ['nullable', Rule::in(['normal', 'backdate'])],
        ])->validate();

        $typeKey = (string) $p['type'];
        $type = $this->types->get($typeKey);
        // A21: a client may only create types it declared (X-Capabilities).
        if ($ctx->capabilities !== null && ! in_array($typeKey, $ctx->capabilities, true)) {
            throw new UnknownHabitType($typeKey);
        }

        try {
            $target = $type->parseTarget($p['target_value']);
        } catch (InvalidHabitValue $e) {
            throw ValidationException::withMessages(['target_value' => [$e->getMessage()]]);
        }
        try {
            $frequency = Frequency::fromArray((string) $p['frequency_type'], (array) $p['frequency_config']);
        } catch (InvalidArgumentException $e) {
            throw ValidationException::withMessages(['frequency_config' => [$e->getMessage()]]);
        }

        $start = LocalDate::fromString((string) $p['start_local_date']);
        $resolver = new DayResolver(UserCalendar::timeline($ctx->userId), $this->clock);
        if ($start->isBefore($resolver->today())) {
            // Spec 05: past start dates require date_mode=backdate within 30 days.
            if (($p['date_mode'] ?? 'normal') !== 'backdate') {
                throw ValidationException::withMessages(['start_local_date' => ['A past start date needs date_mode "backdate".']]);
            }
            $resolver->validateBackdate($start);
        }

        $id = $ctx->mutation->entityId;
        $existing = DB::table('habits')->where('id', $id)->first();
        if ($existing !== null) {
            if ($existing->user_id !== $ctx->userId) {
                throw new ApiException(404, 'not_found', 'Not found.');
            }
            throw ApiException::versionConflict($id, 0, (int) $existing->version, $this->presenter->habit($existing));
        }

        $definition = new DefinitionVersion(1, $start, $typeKey, $target, $p['unit'] ?? null, (string) $p['category'], $frequency);
        $now = UtcTime::format($this->clock->now());
        $frequencyConfig = json_encode((object) $p['frequency_config'], JSON_THROW_ON_ERROR);

        DB::table('habits')->insert([
            'id' => $id,
            'user_id' => $ctx->userId,
            'name' => trim((string) $p['name']),
            'type' => $typeKey,
            'unit' => $definition->unit,
            'category' => $definition->category,
            'target_value' => $type->toStorage($target),
            'frequency_type' => $frequency->type->value,
            'frequency_config' => $frequencyConfig,
            'start_local_date' => $start->toString(),
            'version' => 1,
            'definition_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        DB::table('habit_definition_versions')->insert([
            'id' => (string) Str::uuid7(),
            'habit_id' => $id,
            'version' => 1,
            'effective_date' => $start->toString(),
            'type' => $typeKey,
            'target_value' => $type->toStorage($target),
            'unit' => $definition->unit,
            'category' => $definition->category,
            'frequency_type' => $frequency->type->value,
            'frequency_config' => $frequencyConfig,
            'config' => '{}',
            'created_at' => $now,
        ]);
        DB::table('habit_active_ranges')->insert([
            'id' => (string) Str::uuid7(),
            'habit_id' => $id,
            'starts_on' => $start->toString(),
            'ends_before' => null,
            'created_at' => $now,
        ]);

        $habit = $this->habits->findOwned($ctx->userId, $id);
        $this->journal->append($ctx->userId, 'habit', $id, 'upsert', 1, $this->presenter->habit($habit ?? throw new LogicException('Habit vanished inside its own transaction.')));

        return new HandlerResult('habit', $id, 1);
    }
}
