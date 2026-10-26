<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Notices\NoticeBoard;
use App\Http\Responses\ApiResponse;
use Illuminate\Http\JsonResponse;

/**
 * GET /notices (A57). Read-only and the same for every account: Khay Studios' notices for
 * Today's carousel. Not owner data, so not owner-scoped; it holds no personal data.
 */
final class NoticesController
{
    public function __construct(private readonly NoticeBoard $board) {}

    public function index(): JsonResponse
    {
        return ApiResponse::success($this->board->active());
    }
}
