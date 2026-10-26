<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Ops\OpsStatus;
use App\Http\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * A55: the read-only ops status, numbers only. Built like the tick: its own secret compared in
 * constant time, and a plain 404 for anyone without it, so it is never advertised.
 */
final class OpsStatusController
{
    public function __invoke(Request $request, OpsStatus $status): JsonResponse
    {
        $secret = config()->string('api.ops_secret');
        $given = (string) $request->header('X-Ops-Secret', '');
        if ($secret === '' || ! hash_equals($secret, $given)) {
            throw new NotFoundHttpException;
        }

        return ApiResponse::success($status->collect(), headers: ['Cache-Control' => 'no-store']);
    }
}
