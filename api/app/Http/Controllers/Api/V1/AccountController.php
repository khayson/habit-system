<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Accounts\AccountDeletionService;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use App\Http\Requests\DeleteAccountRequest;
use App\Http\Responses\ApiResponse;
use App\Models\User;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use stdClass;

/**
 * A49: DELETE /me (the password as recent reauthentication) and the receipt-only status read,
 * GET /account-deletions/{id}.
 */
final class AccountController
{
    public function __construct(
        private readonly AccountDeletionService $deletions,
        private readonly Clock $clock,
    ) {}

    public function destroy(DeleteAccountRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        if (! Hash::check((string) $request->validated('password'), (string) $user->password)) {
            throw ValidationException::withMessages(['password' => ['The password is incorrect.']]);
        }
        $result = $this->deletions->delete((string) $user->id);

        return ApiResponse::success([
            ...$this->present($result['deletion']),
            'receipt_token' => $result['receipt_token'],
            'receipt_expires_at' => UtcTime::format(WireTime::parse((string) $result['deletion']->receipt_expires_at)),
        ], 202);
    }

    /** The receipt as a bearer token; anything else is the same 404. */
    public function show(Request $request, string $deletion): JsonResponse
    {
        $receipt = (string) $request->bearerToken();
        $row = $receipt !== '' && Str::isUuid($deletion)
            ? DB::table('account_deletions')->where('id', strtolower($deletion))->first()
            : null;
        if ($row === null
            || ! hash_equals((string) $row->receipt_hash, hash('sha256', $receipt))
            || WireTime::parse((string) $row->receipt_expires_at) <= $this->clock->now()) {
            throw new ApiException(404, 'not_found', 'Not found.');
        }

        return ApiResponse::success($this->present($row));
    }

    /** @return array{id: string, status: string, requested_at: string, completed_at: string|null} */
    private function present(stdClass $row): array
    {
        return [
            'id' => (string) $row->id,
            'status' => (string) $row->status,
            'requested_at' => UtcTime::format(WireTime::parse((string) $row->requested_at)),
            'completed_at' => $row->completed_at === null ? null : UtcTime::format(WireTime::parse((string) $row->completed_at)),
        ];
    }
}
