<?php

namespace App\Domain\Reward;

/**
 * Outcome of re-evaluating one habit-day. When `delta` is non-zero, append one xp_ledger row
 * with (entitlement revision, delta, reason).
 */
final readonly class XpTransition
{
    public function __construct(
        public ?XpEntitlement $entitlement,
        public int $delta,
        /** completion | reversal | recompletion; null when nothing changes. */
        public ?string $reason,
    ) {}

    public function changed(): bool
    {
        return $this->delta !== 0;
    }
}
