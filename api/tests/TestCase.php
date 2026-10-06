<?php

namespace Tests;

use App\Domain\Clock;
use App\Infrastructure\FrozenClock;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function freezeClock(string $instant): FrozenClock
    {
        $clock = new FrozenClock($instant);
        $this->app->instance(Clock::class, $clock);

        return $clock;
    }
}
