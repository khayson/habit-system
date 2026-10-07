<?php

namespace App\Domain\Habit;

/**
 * The stored state of one habit-day (A21): `value` is the scalar the rule evaluates (binary 0/1,
 * quantity thousandths, duration seconds, checklist items done, …); `detail` holds type-specific
 * state such as checklist item states. Built-in types leave `detail` empty.
 */
final readonly class LogState
{
    /**
     * @param  array<string, mixed>  $detail
     */
    public function __construct(
        public int $value,
        public array $detail = [],
    ) {}

    public static function empty(): self
    {
        return new self(0);
    }

    public function withValue(int $value): self
    {
        return new self($value, $this->detail);
    }
}
