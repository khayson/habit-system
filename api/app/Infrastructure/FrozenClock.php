<?php

namespace App\Infrastructure;

use App\Domain\Clock;
use Carbon\CarbonImmutable;

/**
 * Fixed clock for tests and deterministic jobs.
 */
final class FrozenClock implements Clock
{
    private CarbonImmutable $now;

    public function __construct(CarbonImmutable|string $now)
    {
        $this->now = CarbonImmutable::parse($now)->utc();
    }

    public function now(): CarbonImmutable
    {
        return $this->now;
    }

    public function set(CarbonImmutable|string $now): void
    {
        $this->now = CarbonImmutable::parse($now)->utc();
    }
}
