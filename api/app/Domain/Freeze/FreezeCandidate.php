<?php

namespace App\Domain\Freeze;

use DateTimeImmutable;

/** A failed eligible period the closure runner offers for protection. */
final readonly class FreezeCandidate
{
    public function __construct(
        public string $habitId,
        public string $periodKey,
        /** UTC end of the period: closure order (A8) and which opt-in policy applies. */
        public DateTimeImmutable $endsAt,
        /** The streak that a miss would end, for A8 ordering. */
        public int $streakAtRisk,
        public int $definitionVersion,
        public bool $closed = true,
    ) {}

    public function usageKey(): string
    {
        return FreezeUsage::keyOf($this->habitId, $this->periodKey);
    }
}
