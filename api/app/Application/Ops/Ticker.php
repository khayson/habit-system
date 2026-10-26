<?php

namespace App\Application\Ops;

use App\Domain\Clock;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;

/**
 * A54: one tick: the scheduler, then the queue until it is empty. One tick at a time: a tick
 * that finds the lock taken does nothing. The scheduled commands keep withoutOverlapping and
 * the queue reserves each job, so nothing runs twice. Called by the outside timer (TickController)
 * and by the admin page's "run the timer now" (A58).
 */
final readonly class Ticker
{
    /** Longer than the worker's own limit, so the lock never expires under a running tick. */
    private const int LOCK_SECONDS = 120;

    public function __construct(private OpsMetrics $metrics, private Clock $clock) {}

    /** False when another tick holds the lock. */
    public function run(): bool
    {
        $lock = Cache::lock('internal-tick', self::LOCK_SECONDS);
        if (! $lock->get()) {
            return false;
        }
        try {
            set_time_limit(self::LOCK_SECONDS - 10);
            Artisan::call('schedule:run');
            Artisan::call('queue:work', [
                '--stop-when-empty' => true,
                '--max-time' => config()->integer('api.tick_max_seconds'),
                '--memory' => config()->integer('api.tick_memory_mb'),
                '--tries' => 3,
            ]);
            // A55: the ops status shows when the scheduler last ran.
            $this->metrics->recordTick($this->clock->now());
        } finally {
            $lock->release();
        }

        return true;
    }
}
