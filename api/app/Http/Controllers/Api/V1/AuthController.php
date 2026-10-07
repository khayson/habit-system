<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Accounts\AccountService;
use App\Application\Presenters\EntityPresenter;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Responses\ApiResponse;
use App\Models\PersonalAccessToken;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

final class AuthController
{
    /**
     * S6: bcrypt hash of a random secret nobody knows, at the production cost (12, BCRYPT_ROUNDS).
     * A constant, not computed per request: hashing on demand would make unknown emails slower.
     * Regenerate if the production cost changes.
     */
    public const string DUMMY_HASH = '$2y$12$.OwH5ayKmA/Umj4Lurl1TO0Av612WocU96/wb8.DyPWHPS2dnAUn6';

    public function __construct(
        private readonly AccountService $accounts,
        private readonly EntityPresenter $presenter,
    ) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();
        $user = $this->accounts->register($data['name'], $data['email'], $data['password'], $data['timezone']);
        $token = $this->accounts->issueToken($user, $data['device_name'], $data['device_id'] ?? null);

        return ApiResponse::success($this->session($user, $token), 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();
        $user = User::query()->where('email', $data['email'])->first();

        // Same answer, and the same bcrypt work, for an unknown email and a wrong password: no
        // account enumeration by content or by timing (S6).
        $passwordOk = Hash::check($data['password'], $user->password ?? self::DUMMY_HASH);
        if ($user === null || ! $passwordOk) {
            throw ValidationException::withMessages(['email' => ['Email or password is incorrect.']]);
        }

        return ApiResponse::success($this->session($user, $this->accounts->issueToken($user, $data['device_name'], $data['device_id'] ?? null)));
    }

    /** A6 rotation; the old token keeps a 10-minute grace window (A29). */
    public function refresh(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        /** @var PersonalAccessToken $current */
        $current = $user->currentAccessToken();

        return ApiResponse::success(['token' => $this->accounts->refresh($user, $current), 'token_type' => 'Bearer']);
    }

    /** Revokes this device's token. Local data and outboxes on the device are the app's business. */
    public function logout(Request $request): Response
    {
        /** @var User $user */
        $user = $request->user();
        $user->currentAccessToken()->delete();

        return response()->noContent();
    }

    public function logoutAll(Request $request): Response
    {
        /** @var User $user */
        $user = $request->user();
        $user->tokens()->delete();

        return response()->noContent();
    }

    public function me(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();

        return ApiResponse::success($this->presenter->user(DB::table('users')->where('id', $user->id)->first() ?? (object) []));
    }

    /** @return array<string, mixed> */
    private function session(User $user, string $token): array
    {
        return [
            'user' => $this->presenter->user(DB::table('users')->where('id', $user->id)->first() ?? (object) []),
            'token' => $token,
            'token_type' => 'Bearer',
        ];
    }
}
