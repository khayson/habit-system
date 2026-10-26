<?php

namespace App\Http\Controllers\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Cache;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * A54: Render's free tier has no cron and no worker, so an outside timer (cron-job.org, every 5
 * minutes) calls this to run the scheduler and then the queue until it is empty. Guarded by a
 * shared secret compared in constant time; anything else is a plain 404 so the endpoint is never
 * advertised. One tick at a time: a tick that finds the lock taken does nothing. The scheduled
 * commands keep withoutOverlapping and the queue reserves each job, so nothing runs twice.
 */
final class TickController
{
    /** Longer than the worker's own limit, so the lock never expires under a running tick. */
    private const int LOCK_SECONDS = 120;

    public function __invoke(Request $request): Response
    {
        $secret = config()->string('api.tick_secret');
        $given = (string) $request->header('X-Tick-Secret', '');
        if ($secret === '' || ! hash_equals($secret, $given)) {
            throw new NotFoundHttpException;
        }

        $lock = Cache::lock('internal-tick', self::LOCK_SECONDS);
        if (! $lock->get()) {
            return response()->noContent();
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
        } finally {
            $lock->release();
        }

        return response()->noContent();
    }
}
