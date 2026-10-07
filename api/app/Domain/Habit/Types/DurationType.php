<?php

namespace App\Domain\Habit\Types;

use App\Domain\Habit\Aggregation;
use App\Domain\Habit\EvaluationTiming;
use App\Domain\Habit\HabitType;
use App\Domain\Habit\InvalidHabitValue;
use App\Domain\Habit\UnsupportedOperation;

/** Duration in whole seconds (invariant 10). */
final class DurationType implements HabitType
{
    // ASSUMPTION(A1-duration-max): one habit-day holds at most 25 hours (the fall-back day).
    public const int MAX_SECONDS = 25 * 3600;

    public function key(): string
    {
        return 'duration';
    }

    public function parseValue(mixed $wire): int
    {
        if (! is_int($wire) || $wire < 0 || $wire > self::MAX_SECONDS) {
            throw new InvalidHabitValue('Durations are whole seconds between 0 and 90000.');
        }

        return $wire;
    }

    public function formatValue(int $units): int
    {
        return $units;
    }

    public function parseTarget(mixed $wire): int
    {
        $seconds = $this->parseValue($wire);
        if ($seconds <= 0) {
            throw new InvalidHabitValue('Duration must be greater than zero.');
        }

        return $seconds;
    }

    public function operations(): array
    {
        return ['log.increment_duration', 'log.increment', 'log.set_value'];
    }

    public function apply(string $operation, int $current, mixed $operand): int
    {
        return match ($operation) {
            'log.set_value' => $this->parseValue($operand),
            'log.increment_duration', 'log.increment' => $this->increment($current, $this->parseValue($operand)),
            default => throw new UnsupportedOperation($this->key(), $operation),
        };
    }

    public function isComplete(int $value, int $target): bool
    {
        return $value >= $target;
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
        if ($current + $delta > self::MAX_SECONDS) {
            throw new InvalidHabitValue('The daily total would exceed 25 hours.');
        }

        return $current + $delta;
    }
}
