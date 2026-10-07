<?php

namespace App\Domain\Habit;

/**
 * Everything type-specific about a habit lives behind this strategy (A21). Code outside the
 * registry never switches on a type key.
 *
 * Values are integer "units" so arithmetic is exact: binary 0/1, quantity thousandths
 * (numeric(12,3)), duration whole seconds. Wire values are converted at the edge.
 */
interface HabitType
{
    /** Stable key stored in habits.type, e.g. "binary". */
    public function key(): string;

    /**
     * Wire value to units. Rejects floats, wrong shapes and out-of-range values.
     *
     * @throws InvalidHabitValue
     */
    public function parseValue(mixed $wire): int;

    /** Units to wire value (int for binary/duration, decimal string for quantity). */
    public function formatValue(int $units): int|string;

    /**
     * Wire target to units, enforcing the type's target rule.
     *
     * @throws InvalidHabitValue
     */
    public function parseTarget(mixed $wire): int;

    /**
     * Log operations this type accepts (spec 07 names and A21 generic names).
     *
     * @return list<string>
     */
    public function operations(): array;

    /**
     * New stored value after an operation. Increments are positive and commute.
     *
     * @throws UnsupportedOperation
     * @throws InvalidHabitValue
     */
    public function apply(string $operation, int $current, mixed $operand): int;

    /** Completion predicate for one habit-day against the effective target. */
    public function isComplete(int $value, int $target): bool;

    public function evaluation(): EvaluationTiming;

    public function earnsXp(): bool;

    public function aggregation(): Aggregation;
}
