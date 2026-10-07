<?php

namespace App\Domain\Habit;

/**
 * Everything type-specific about a habit lives behind this strategy (A21). Code outside the
 * registry never switches on a type key.
 *
 * A habit-day is a LogState: `value` is an integer in the type's units so arithmetic is exact
 * (binary 0/1, quantity thousandths, duration whole seconds), `detail` carries type-specific
 * state. Operations and completion see the effective DefinitionVersion, including its `config`
 * (for example checklist item ids), so new types need no engine change.
 */
interface HabitType
{
    /** Stable key stored in habits.type, e.g. "binary". */
    public function key(): string;

    /**
     * Wire scalar value to units. Rejects floats, wrong shapes and out-of-range values.
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
     * Canonical log operations this type accepts (A27): log.set_value, log.increment,
     * log.set_item, log.set_note.
     *
     * @return list<string>
     */
    public function operations(): array;

    /**
     * Legacy spec operation names accepted for this type, alias => canonical (A27). Normalised
     * by HabitTypeRegistry::canonicalOperation(), never by callers.
     *
     * @return array<string, string>
     */
    public function operationAliases(): array;

    /**
     * New state after a canonical operation. Increments are positive and commute.
     *
     * @throws UnsupportedOperation
     * @throws InvalidHabitValue
     */
    public function apply(string $operation, LogState $current, mixed $operand, DefinitionVersion $definition): LogState;

    /** Completion predicate for one habit-day against its effective definition. */
    public function isComplete(LogState $state, DefinitionVersion $definition): bool;

    public function evaluation(): EvaluationTiming;

    public function earnsXp(): bool;

    public function aggregation(): Aggregation;
}
