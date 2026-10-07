<?php

namespace App\Domain\Insights;

final readonly class Consistency
{
    public function __construct(
        public int $completed,
        public int $eligible,
        /** Rounded half up; null when nothing is eligible yet. */
        public ?int $percent,
    ) {}
}
