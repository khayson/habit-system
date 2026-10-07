<?php

namespace App\Domain\Reward;

/** The single entitlement of one (habit, local date). Never recreated, only revised. */
final readonly class XpEntitlement
{
    public function __construct(
        public XpEntitlementState $state,
        public int $revision,
    ) {}
}
