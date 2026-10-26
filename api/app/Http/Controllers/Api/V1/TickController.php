<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Ops\Ticker;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * A54: Render's free tier has no cron and no worker, so an outside timer (cron-job.org, every 5
 * minutes) calls this to run one tick (Ticker). Guarded by a shared secret compared in constant
 * time; anything else is a plain 404 so the endpoint is never advertised.
 */
final class TickController
{
    public function __invoke(Request $request, Ticker $ticker): Response
    {
        $secret = config()->string('api.tick_secret');
        $given = (string) $request->header('X-Tick-Secret', '');
        if ($secret === '' || ! hash_equals($secret, $given)) {
            throw new NotFoundHttpException;
        }
        $ticker->run();

        return response()->noContent();
    }
}
