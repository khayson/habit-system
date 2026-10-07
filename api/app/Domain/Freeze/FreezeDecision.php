<?php

namespace App\Domain\Freeze;

final readonly class FreezeDecision
{
    public function __construct(
        public FreezeCandidate $candidate,
        public FreezeOutcome $outcome,
    ) {}

    public function isProtected(): bool
    {
        return $this->outcome === FreezeOutcome::Spent;
    }
}
