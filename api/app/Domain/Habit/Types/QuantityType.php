<?php

namespace App\Domain\Habit\Types;

use App\Domain\Habit\Aggregation;
use App\Domain\Habit\DefinitionVersion;
use App\Domain\Habit\EvaluationTiming;
use App\Domain\Habit\HabitType;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\LogState;
use App\Domain\Habit\StoredDecimal;
use App\Domain\Habit\UnsupportedOperation;

/**
 * Exact-decimal quantity, numeric(12,3). Units are thousandths; the wire form is a decimal
 * string with up to three decimals ("250.000"). Floats are never accepted (invariant 10).
 */
final class QuantityType implements HabitType
{
    /** 999,999,999.999 in thousandths. */
    public const int MAX_UNITS = 999_999_999_999;

    public function key(): string
    {
        return 'quantity';
    }

    public function parseValue(mixed $wire): int
    {
        if (! is_string($wire) || preg_match('/^(0|[1-9]\d{0,8})(?:\.(\d{1,3}))?$/', $wire, $m) !== 1) {
            throw new InvalidHabitValue('Quantities are decimal strings with up to 3 decimals, e.g. "250.000".');
        }

        return (int) $m[1] * 1000 + (int) str_pad($m[2] ?? '', 3, '0');
    }

    public function formatValue(int $units): string
    {
        return intdiv($units, 1000).'.'.str_pad((string) ($units % 1000), 3, '0', STR_PAD_LEFT);
    }

    public function toStorage(int $units): string
    {
        return StoredDecimal::fromUnits($units, 3);
    }

    public function fromStorage(string $stored): int
    {
        return StoredDecimal::toUnits($stored, 3);
    }

    public function parseTarget(mixed $wire): int
    {
        $units = $this->parseValue($wire);
        if ($units <= 0) {
            throw new InvalidHabitValue('A quantity target must be greater than zero.');
        }

        return $units;
    }

    public function operations(): array
    {
        return ['log.set_value', 'log.increment'];
    }

    public function operationAliases(): array
    {
        return ['log.increment_quantity' => 'log.increment'];
    }

    public function apply(string $operation, LogState $current, mixed $operand, DefinitionVersion $definition): LogState
    {
        return match ($operation) {
            'log.set_value' => $current->withValue($this->parseValue($operand)),
            'log.increment' => $current->withValue($this->increment($current->value, $this->parseValue($operand))),
            default => throw new UnsupportedOperation($this->key(), $operation),
        };
    }

    public function isComplete(LogState $state, DefinitionVersion $definition): bool
    {
        return $state->value >= $definition->target;
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
        return Aggregation::Sum;
    }

    private function increment(int $current, int $delta): int
    {
        if ($delta <= 0) {
            throw new InvalidHabitValue('An increment must be greater than zero.');
        }
        if ($current + $delta > self::MAX_UNITS) {
            throw new InvalidHabitValue('The daily total would exceed the maximum.');
        }

        return $current + $delta;
    }
}
