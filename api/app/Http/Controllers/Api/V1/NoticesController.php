<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Notices\NoticeBoard;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * GET /notices (A57). Read-only: Khay Studios' notices for Today's carousel, those for everyone
 * and those addressed to the caller. Recipient lists are never sent.
 */
final class NoticesController
{
    public function __construct(private readonly NoticeBoard $board) {}

    public function index(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return ApiResponse::success($this->board->activeFor($user->id));
    }
}
