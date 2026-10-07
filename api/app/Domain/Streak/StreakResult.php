<?php

namespace App\Domain\Streak;

final readonly class StreakResult
{
    public function __construct(
        public int $current,
        public int $longest,
        /** days | periods | weeks (spec 02: the unit is shown explicitly). */
        public string $unit,
    ) {}
}
