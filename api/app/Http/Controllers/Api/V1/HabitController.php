<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Habits\HabitRepository;
use App\Application\Periods\HeatmapService;
use App\Domain\Calendar\LocalDate;
use App\Exceptions\ApiException;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

final class HabitController
{
    public function __construct(
        private readonly HabitRepository $habits,
        private readonly HeatmapService $heatmap,
    ) {}

    /** GET /habits/{id}/heatmap?from=&to= (spec 06): local dates, at most 366 days. */
    public function heatmap(Request $request, string $habit): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        // Malformed, missing and foreign ids are one answer (invariant 2).
        $row = Str::isUuid($habit) ? $this->habits->findOwned($user->id, strtolower($habit)) : null;
        if ($row === null) {
            throw new ApiException(404, 'not_found', 'Not found.');
        }

        $data = Validator::make($request->query(), [
            'from' => ['required', 'date_format:Y-m-d'],
            'to' => ['required', 'date_format:Y-m-d', 'after_or_equal:from'],
        ])->validate();
        $from = LocalDate::fromString((string) $data['from']);
        $to = LocalDate::fromString((string) $data['to']);
        if ($from->daysUntil($to) + 1 > HeatmapService::MAX_DAYS) {
            throw ValidationException::withMessages(['to' => ['Choose a window of at most 366 days.']]);
        }

        return ApiResponse::success($this->heatmap->build($user->id, $row, $from, $to));
    }
}
