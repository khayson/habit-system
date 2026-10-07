<?php

namespace Tests\Support;

use App\Domain\Habit\Aggregation;
use App\Domain\Habit\DefinitionVersion;
use App\Domain\Habit\EvaluationTiming;
use App\Domain\Habit\HabitType;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\LogState;
use App\Domain\Habit\StoredDecimal;
use App\Domain\Habit\UnsupportedOperation;

/**
 * Test-only checklist (EXPANSION_PLAN §2): item ids in definition `config.items`, item states in
 * log `detail.items`, `value` = items done, complete when all items are done. Proves R2: a
 * non-scalar type fits the interface without engine changes. Not registered in production.
 */
final class FakeChecklistType implements HabitType
{
    public function key(): string
    {
        return 'checklist';
    }

    public function parseValue(mixed $wire): int
    {
        if (! is_int($wire) || $wire < 0) {
            throw new InvalidHabitValue('Checklist values count items done.');
        }

        return $wire;
    }

    public function formatValue(int $units): int
    {
        return $units;
    }

    public function normalizeUnit(?string $unit): ?string
    {
        if ($unit !== null && trim($unit) !== '') {
            throw new InvalidHabitValue('A checklist has no unit.');
        }

        return null;
    }

    public function toStorage(int $units): string
    {
        return StoredDecimal::fromUnits($units, 0);
    }

    public function fromStorage(string $stored): int
    {
        return StoredDecimal::toUnits($stored, 0);
    }

    public function parseTarget(mixed $wire): int
    {
        $target = $this->parseValue($wire);
        if ($target < 1) {
            throw new InvalidHabitValue('A checklist needs at least one item.');
        }

        return $target;
    }

    public function operations(): array
    {
        return ['log.set_item'];
    }

    public function operationAliases(): array
    {
        return [];
    }

    public function apply(string $operation, LogState $current, mixed $operand, DefinitionVersion $definition): LogState
    {
        if ($operation !== 'log.set_item') {
            throw new UnsupportedOperation($this->key(), $operation);
        }
        $items = $this->items($definition);
        if (! is_array($operand) || ! is_string($operand['item_id'] ?? null) || ! is_bool($operand['done'] ?? null)
            || ! in_array($operand['item_id'], $items, true)) {
            throw new InvalidHabitValue('Unknown checklist item.');
        }

        /** @var array<string, bool> $states */
        $states = is_array($current->detail['items'] ?? null) ? $current->detail['items'] : [];
        $states[$operand['item_id']] = $operand['done'];

        return new LogState(count(array_filter($states)), ['items' => $states]);
    }

    public function isComplete(LogState $state, DefinitionVersion $definition): bool
    {
        return $state->value >= count($this->items($definition));
    }

    public function evaluation(): EvaluationTiming
    {
        return EvaluationTiming::Immediate;
    }

    public function earnsXp(): bool
    {
        return true;
    }

    public function aggregation(): Aggregation
    {
        return Aggregation::Count;
    }

    /** @return list<string> */
    private function items(DefinitionVersion $definition): array
    {
        $items = $definition->config['items'] ?? [];

        return is_array($items) ? array_values(array_filter($items, 'is_string')) : [];
    }
}
