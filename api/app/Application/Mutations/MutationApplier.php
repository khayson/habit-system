<?php

namespace App\Application\Mutations;

use App\Application\Habits\HabitRepository;
use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\Handlers\HabitCreate;
use App\Application\Mutations\Handlers\LogDelete;
use App\Application\Mutations\Handlers\LogSetValue;
use App\Domain\Calendar\LocalDate;
use App\Domain\Clock;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\UnsupportedOperation;
use App\Exceptions\ApiException;
use App\Exceptions\DomainErrorMapper;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

/**
 * The only code that changes domain state (invariant 4). /sync and any REST adapter call
 * apply(); nothing else writes habits or logs.
 *
 * One transaction per mutation (batch partial success, spec 07):
 *   begin → lock the user row → receipt lookup (same hash → stored ack, duplicate; different
 *   hash → idempotency_mismatch) → handler in a savepoint → receipt → commit.
 * Handlers write domain rows and journal rows (seq = ++users.change_seq) in that transaction.
 */
final readonly class MutationApplier
{
    private const string OCCURRED_AT = '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$/';

    public function __construct(
        private ChangeJournal $journal,
        private HabitRepository $habits,
        private HabitTypeRegistry $types,
        private HabitCreate $habitCreate,
        private LogSetValue $logSetValue,
        private LogDelete $logDelete,
        private Clock $clock,
    ) {}

    /**
     * @param  array<mixed>  $raw  one mutation object exactly as the client sent it
     * @param  list<string>|null  $capabilities
     */
    public function apply(string $userId, ?string $deviceId, array $raw, ?array $capabilities = null): MutationAck
    {
        $mutationId = is_string($raw['mutation_id'] ?? null) ? $raw['mutation_id'] : null;

        try {
            $mutation = $this->parse($raw);
        } catch (ValidationException $e) {
            return new MutationAck($mutationId, MutationAck::REJECTED, error: self::validationError($e));
        }
        $hash = PayloadHash::of($raw);

        return DB::transaction(function () use ($userId, $deviceId, $mutation, $hash, $capabilities): MutationAck {
            $this->journal->lockUser($userId);

            $receipt = DB::table('mutation_receipts')->where('user_id', $userId)->where('mutation_id', $mutation->mutationId)->first();
            if ($receipt !== null) {
                if (! hash_equals((string) $receipt->payload_hash, $hash)) {
                    return self::failed($mutation, ApiException::idempotencyMismatch());
                }

                return MutationAck::fromStored(HabitRepository::json($receipt->result), duplicate: true);
            }

            $context = new MutationContext($userId, $deviceId, $mutation, $capabilities);
            try {
                [$operation, $ack] = DB::transaction(fn () => $this->dispatch($context));
            } catch (DependencyPending) {
                return new MutationAck($mutation->mutationId, MutationAck::DEPENDENCY_PENDING, entity: $mutation->entity, entityId: $mutation->entityId);
            } catch (ValidationException $e) {
                [$operation, $ack] = [$mutation->operation, new MutationAck($mutation->mutationId, MutationAck::REJECTED, error: self::validationError($e))];
            } catch (ApiException $e) {
                [$operation, $ack] = [$mutation->operation, self::failed($mutation, $e)];
            } catch (\DomainException $e) {
                $mapped = DomainErrorMapper::toApiException($e) ?? throw $e;
                [$operation, $ack] = [$mutation->operation, self::failed($mutation, $mapped)];
            }

            DB::table('mutation_receipts')->insert([
                'user_id' => $userId,
                'mutation_id' => $mutation->mutationId,
                'device_id' => $deviceId,
                // A27: receipts store the canonical operation name.
                'operation' => $operation,
                'payload_hash' => $hash,
                'result' => json_encode($ack->toArray(), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES),
                'committed_at' => UtcTime::format($this->clock->now()),
            ]);

            return $ack;
        }, 3);
    }

    /**
     * Routes by entity and canonical operation; never by habit type (invariant 14).
     *
     * @return array{string, MutationAck}
     */
    private function dispatch(MutationContext $ctx): array
    {
        $m = $ctx->mutation;

        if ($m->entity === 'habit' && $m->operation === 'habit.create') {
            return [$m->operation, self::accepted($m, $this->habitCreate->handle($ctx))];
        }

        if ($m->entity === 'habit_log' && $m->operation === 'log.delete') {
            return [$m->operation, self::accepted($m, $this->logDelete->handle($ctx))];
        }

        if ($m->entity === 'habit_log' && str_starts_with($m->operation, 'log.')) {
            $habitId = $m->payload['habit_id'] ?? null;
            if (! is_string($habitId) || Validator::make(['habit_id' => $habitId], ['habit_id' => 'uuid'])->fails()) {
                throw ValidationException::withMessages(['habit_id' => ['A valid habit_id is required.']]);
            }
            $habit = $this->habits->findOwned($ctx->userId, $habitId) ?? throw new DependencyPending;
            // A27: aliases are normalised in one place, against the habit's own type.
            $operation = $this->types->canonicalOperation((string) $habit->type, $m->operation);

            return match ($operation) {
                'log.set_value' => [$operation, self::accepted($m, $this->logSetValue->handle($ctx, $habit))],
                default => throw new UnsupportedOperation((string) $habit->type, $operation),
            };
        }

        throw new UnsupportedOperation($m->entity, $m->operation);
    }

    /** @param array<mixed> $raw */
    private function parse(array $raw): Mutation
    {
        $v = Validator::make($raw, [
            'mutation_id' => ['required', 'uuid'],
            'entity' => ['required', 'string', 'max:32'],
            'entity_id' => ['required', 'uuid'],
            'operation' => ['required', 'string', 'max:48'],
            'base_version' => ['nullable', 'integer', 'min:0'],
            'occurred_at' => ['required', 'string', 'regex:'.self::OCCURRED_AT],
            'captured_timezone' => ['nullable', 'string', 'max:64'],
            'local_date_hint' => ['nullable', 'date_format:Y-m-d'],
            'payload' => ['present', 'array'],
        ]);
        $data = $v->validate();

        return new Mutation(
            strtolower((string) $data['mutation_id']),
            (string) $data['entity'],
            strtolower((string) $data['entity_id']),
            (string) $data['operation'],
            isset($data['base_version']) ? (int) $data['base_version'] : null,
            WireTime::parse((string) $data['occurred_at']),
            isset($data['captured_timezone']) ? (string) $data['captured_timezone'] : null,
            isset($data['local_date_hint']) ? LocalDate::fromString((string) $data['local_date_hint']) : null,
            (array) $data['payload'],
            $raw,
        );
    }

    private static function accepted(Mutation $m, HandlerResult $result): MutationAck
    {
        return new MutationAck($m->mutationId, MutationAck::ACCEPTED, false, $result->entity, $result->entityId, $result->version, $result->resolvedDate);
    }

    private static function failed(Mutation $m, ApiException $e): MutationAck
    {
        // Review needed (stale edit, deleted target) is a conflict; anything else is rejected.
        $status = in_array($e->errorCode, ['version_conflict', 'resource_deleted'], true) ? MutationAck::CONFLICT : MutationAck::REJECTED;

        return new MutationAck($m->mutationId, $status, false, $m->entity, $m->entityId, error: [
            'code' => $e->errorCode,
            'message' => $e->getMessage(),
            ...$e->extra,
        ]);
    }

    /** @return array<string, mixed> */
    private static function validationError(ValidationException $e): array
    {
        return ['code' => 'validation_failed', 'message' => 'Check the highlighted fields.', 'fields' => $e->errors()];
    }
}
