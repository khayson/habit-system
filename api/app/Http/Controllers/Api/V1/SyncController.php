<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Sync\BootstrapService;
use App\Application\Sync\SyncService;
use App\Http\Requests\SyncRequest;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

final class SyncController
{
    public function __construct(
        private readonly SyncService $sync,
        private readonly BootstrapService $bootstrap,
    ) {}

    /** POST /sync: per-mutation acks plus a bounded pull. HTTP 200 never means all accepted. */
    public function sync(SyncRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $data = $request->validated();

        return ApiResponse::success($this->sync->sync(
            $user->id,
            strtolower((string) $data['device_id']),
            $data['cursor'] ?? null,
            (int) ($data['pull_limit'] ?? SyncService::DEFAULT_PULL_LIMIT),
            array_values($data['mutations']),
            $request->capabilities(),
        ));
    }

    /** GET /sync/bootstrap?cursor=&limit= (A2). */
    public function bootstrap(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $cursor = $request->query('cursor');
        $limit = $request->query('limit', (string) BootstrapService::DEFAULT_LIMIT);
        if (($cursor !== null && ! is_string($cursor)) || ! is_string($limit) || ! ctype_digit($limit)
            || (int) $limit < 1 || (int) $limit > BootstrapService::MAX_LIMIT) {
            throw ValidationException::withMessages(['limit' => ['Use a cursor string and a limit between 1 and 500.']]);
        }

        return ApiResponse::success($this->bootstrap->page($user->id, $cursor, (int) $limit));
    }
}
