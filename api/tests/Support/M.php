<?php

namespace Tests\Support;

use Illuminate\Support\Str;

/** Mutation envelope builders for /sync tests (spec 07 shapes). */
final class M
{
    /**
     * @param  array<string, mixed>  $overrides  payload overrides
     * @return array<string, mixed>
     */
    public static function habitCreate(string $habitId, string $type = 'binary', mixed $target = 1, array $overrides = [], ?string $mutationId = null, string $occurredAt = '2026-05-28T17:00:00Z'): array
    {
        return [
            'mutation_id' => $mutationId ?? (string) Str::uuid7(),
            'entity' => 'habit',
            'entity_id' => $habitId,
            'operation' => 'habit.create',
            'base_version' => null,
            'occurred_at' => $occurredAt,
            'captured_timezone' => 'America/Los_Angeles',
            'payload' => [
                'name' => 'Morning plan',
                'type' => $type,
                'target_value' => $target,
                'unit' => null,
                'category' => 'productivity',
                'frequency_type' => 'daily',
                'frequency_config' => [],
                'start_local_date' => '2026-05-28',
                ...$overrides,
            ],
        ];
    }

    /** @return array<string, mixed> */
    public static function setValue(string $habitId, mixed $value, int $baseVersion, string $occurredAt = '2026-05-28T17:15:00Z', ?string $mutationId = null, ?string $logId = null, string $operation = 'log.set_value', ?string $capturedTimezone = 'America/Los_Angeles'): array
    {
        return array_filter([
            'mutation_id' => $mutationId ?? (string) Str::uuid7(),
            'entity' => 'habit_log',
            'entity_id' => $logId ?? (string) Str::uuid7(),
            'operation' => $operation,
            'base_version' => $baseVersion,
            'occurred_at' => $occurredAt,
            'captured_timezone' => $capturedTimezone,
            'payload' => ['habit_id' => $habitId, 'value' => $value],
        ], fn ($v) => $v !== null);
    }

    /** @return array<string, mixed> */
    public static function setTimezone(string $userId, string $timezone, int $baseVersion, string $occurredAt = '2026-05-28T17:20:00Z', ?string $mutationId = null): array
    {
        return [
            'mutation_id' => $mutationId ?? (string) Str::uuid7(),
            'entity' => 'user',
            'entity_id' => $userId,
            'operation' => 'profile.set_timezone',
            'base_version' => $baseVersion,
            'occurred_at' => $occurredAt,
            'payload' => ['timezone' => $timezone],
        ];
    }

    /**
     * Phase 3.2b: a reminder mutation from contract-fixtures/sync/reminder_mutations.json, with
     * real ids and optional payload overrides.
     *
     * @param  'create'|'update'|'delete'  $step
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    public static function reminder(string $step, string $reminderId, ?string $habitId = null, ?int $baseVersion = null, array $payload = [], ?string $mutationId = null): array
    {
        $fixture = json_decode((string) file_get_contents(contractFixturePath('sync/reminder_mutations.json')), true, flags: JSON_THROW_ON_ERROR);
        $m = $fixture[$step]['mutation'];
        $m['mutation_id'] = $mutationId ?? (string) Str::uuid7();
        $m['entity_id'] = $reminderId;
        if ($step === 'create') {
            $m['payload']['habit_id'] = $habitId;
        } else {
            $m['base_version'] = $baseVersion ?? $m['base_version'];
        }
        $m['payload'] = [...$m['payload'], ...$payload];

        return $m;
    }

    /** @return array<string, mixed> */
    public static function delete(string $logId, int $baseVersion, string $habitId, ?string $mutationId = null): array
    {
        return [
            'mutation_id' => $mutationId ?? (string) Str::uuid7(),
            'entity' => 'habit_log',
            'entity_id' => $logId,
            'operation' => 'log.delete',
            'base_version' => $baseVersion,
            'occurred_at' => '2026-05-28T17:20:00Z',
            'payload' => ['habit_id' => $habitId],
        ];
    }
}
