<?php

namespace App\Domain\Freeze;

/** One freeze_usage row: UNIQUE(habit_id, period_key), at most one refund. */
final readonly class FreezeUsage
{
    public function __construct(
        public string $habitId,
        public string $periodKey,
        public FreezeUsageState $state,
        public ?int $definitionVersion = null,
    ) {}

    public function key(): string
    {
        return self::keyOf($this->habitId, $this->periodKey);
    }

    public static function keyOf(string $habitId, string $periodKey): string
    {
        return $habitId.'|'.$periodKey;
    }

    public function refunded(): self
    {
        return new self($this->habitId, $this->periodKey, FreezeUsageState::Refunded, $this->definitionVersion);
    }
}
