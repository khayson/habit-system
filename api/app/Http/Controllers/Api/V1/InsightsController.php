<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Insights\InsightsQuery;
use App\Domain\Habit\DefinitionVersion;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/** GET /insights (A47). Read-only; the app writes through /sync only (A14). */
final class InsightsController
{
    public function __construct(private readonly InsightsQuery $query) {}

    public function show(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $query = $request->query();
        // Only these parameters: the window is never a client date (A47).
        foreach (array_keys($query) as $key) {
            if (! in_array($key, ['period', 'category'], true)) {
                throw ValidationException::withMessages([(string) $key => ['This parameter is not supported.']]);
            }
        }
        $data = Validator::make($query, [
            'period' => ['required', Rule::in(InsightsQuery::PERIODS)],
            'category' => ['sometimes', 'string', Rule::in(DefinitionVersion::CATEGORIES)],
        ])->validate();

        return ApiResponse::success($this->query->build($user->id, (string) $data['period'], $data['category'] ?? null));
    }
}
