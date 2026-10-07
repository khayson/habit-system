<?php

namespace App\Domain\Freeze;

use DateTimeImmutable;

/** One user_freeze_policy_versions row (spec 08). */
final readonly class FreezePolicyVersion
{
    public function __construct(
        public bool $enabled,
        public DateTimeImmutable $effectiveAt,
    ) {}
}
