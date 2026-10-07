<?php

namespace App\Domain\Habit\Types;

use App\Domain\Habit\Aggregation;
use App\Domain\Habit\EvaluationTiming;
use App\Domain\Habit\HabitType;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\UnsupportedOperation;

/** Yes/no habit: value 0 or 1, target fixed at 1. */
final class BinaryType implements HabitType
{
    public function key(): string
    {
        return 'binary';
    }

    public function parseValue(mixed $wire): int
    {
        if ($wire !== 0 && $wire !== 1) {
            throw new InvalidHabitValue('Binary values are 0 or 1.');
        }

        return $wire;
    }

    public function formatValue(int $units): int
    {
        return $units;
    }

    public function parseTarget(mixed $wire): int
    {
        if ($wire !== 1) {
            throw new InvalidHabitValue('A yes/no habit has a fixed target of 1.');
        }

        return 1;
    }

    public function operations(): array
    {
        return ['log.set_binary', 'log.set_value'];
    }

    public function apply(string $operation, int $current, mixed $operand): int
    {
        if (! in_array($operation, $this->operations(), true)) {
            throw new UnsupportedOperation($this->key(), $operation);
        }

        return $this->parseValue($operand);
    }

    public function isComplete(int $value, int $target): bool
    {
        return $value >= 1;
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
}
