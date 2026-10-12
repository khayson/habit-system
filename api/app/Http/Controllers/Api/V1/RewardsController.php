<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Rewards\RewardsQuery;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/** Read-only reward views (A39 to A42). Nothing here writes; the app writes through /sync. */
final class RewardsController
{
    public function __construct(private readonly RewardsQuery $query) {}

    /** GET /rewards?limit=&cursor= */
    public function rewards(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        [$cursor, $limit] = self::paging($request);

        return ApiResponse::success($this->query->rewards($user->id, $cursor, $limit));
    }

    /** GET /freezes?limit=&cursor= */
    public function freezes(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        [$cursor, $limit] = self::paging($request);

        return ApiResponse::success($this->query->freezes($user->id, $cursor, $limit));
    }

    /** @return array{?string, int} */
    private static function paging(Request $request): array
    {
        $cursor = $request->query('cursor');
        $limit = $request->query('limit', (string) RewardsQuery::DEFAULT_LIMIT);
        if (($cursor !== null && ! is_string($cursor)) || ! is_string($limit) || ! ctype_digit($limit)
            || (int) $limit < 1 || (int) $limit > RewardsQuery::MAX_LIMIT) {
            throw ValidationException::withMessages(['limit' => ['Use a cursor string and a limit between 1 and 50.']]);
        }

        return [$cursor, (int) $limit];
    }
}
