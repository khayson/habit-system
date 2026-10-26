<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Export\ManifestSigner;
use App\Domain\Export\SigningKeyCheck;
use App\Http\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Throwable;

final class HealthController
{
    public function __invoke(): JsonResponse
    {
        if (! app()->environment(['local', 'testing'])) {
            $this->checkExportKey();
            $this->checkMail();
            $this->checkDatabase();
        }

        return ApiResponse::success(['status' => 'ok']);
    }

    /**
     * 6.1 review L3: a test or short export key makes the service unhealthy (503 unavailable),
     * so a deploy's health check stops it. A missing key is logged and stays healthy: only
     * exports fail. The reason goes to the log, never to the caller.
     */
    private function checkExportKey(): void
    {
        $kid = config()->string('api.export_signing_kid');
        $problem = SigningKeyCheck::problem(ManifestSigner::parseKeys(config()->string('api.export_signing_keys')), $kid);
        if ($problem === SigningKeyCheck::MISSING) {
            Log::warning('export signing key not set: exports will fail', ['kid' => $kid]);
        } elseif ($problem !== null) {
            Log::critical('export signing key unusable', ['kid' => $kid, 'reason' => $problem]);
            throw new HttpException(503);
        }
    }

    /**
     * A54 (the 6.4 review's answer): mail that only reaches the log, or a sender nobody can
     * answer, means reset codes never arrive.
     */
    private function checkMail(): void
    {
        $mailer = (string) config('mail.default');
        if (in_array($mailer, ['log', 'array'], true)) {
            Log::critical('mail not deliverable', ['reason' => 'mailer_'.$mailer]);
            throw new HttpException(503);
        }
        $from = strtolower(trim((string) config('mail.from.address')));
        if ($from === '' || str_ends_with($from, 'example.com')) {
            Log::critical('mail not deliverable', ['reason' => 'sender']);
            throw new HttpException(503);
        }
    }

    /** A54: the database answers a trivial query (libpq's PGCONNECT_TIMEOUT bounds a dead host). */
    private function checkDatabase(): void
    {
        try {
            DB::select('SELECT 1');
        } catch (Throwable) {
            Log::critical('database not answering', []);
            throw new HttpException(503);
        }
    }
}
