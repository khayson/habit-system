<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Export\ManifestSigner;
use App\Domain\Export\SigningKeyCheck;
use App\Http\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpKernel\Exception\HttpException;

final class HealthController
{
    public function __invoke(): JsonResponse
    {
        $this->checkExportKey();

        return ApiResponse::success(['status' => 'ok']);
    }

    /**
     * 6.1 review L3: outside local and testing, a test or short export key makes the service
     * unhealthy (503 unavailable), so a deploy's health check stops it. A missing key is logged
     * and stays healthy: only exports fail. The reason goes to the log, never to the caller.
     */
    private function checkExportKey(): void
    {
        if (app()->environment(['local', 'testing'])) {
            return;
        }
        $kid = config()->string('api.export_signing_kid');
        $problem = SigningKeyCheck::problem(ManifestSigner::parseKeys(config()->string('api.export_signing_keys')), $kid);
        if ($problem === SigningKeyCheck::MISSING) {
            Log::warning('export signing key not set: exports will fail', ['kid' => $kid]);
        } elseif ($problem !== null) {
            Log::critical('export signing key unusable', ['kid' => $kid, 'reason' => $problem]);
            throw new HttpException(503);
        }
    }
}
