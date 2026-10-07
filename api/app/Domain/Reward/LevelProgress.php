<?php

namespace App\Domain\Reward;

/** Server-computed level fields (A9). The client never evaluates the formula. */
final readonly class LevelProgress
{
    public function __construct(
        public int $xp,
        public int $level,
        public int $progressIntoLevel,
        public int $nextLevelThreshold,
    ) {}
}
