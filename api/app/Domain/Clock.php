<?php

namespace App\Domain;

use Carbon\CarbonImmutable;

/**
 * The only source of "now". Domain classes receive it by injection and never call now().
 */
interface Clock
{
    /** Current instant, always in UTC. */
    public function now(): CarbonImmutable;
}
