<?php

namespace App\Http\Controllers\Api\V1;

use App\Application\Accounts\PasswordResetService;
use App\Http\Requests\ForgotPasswordRequest;
use App\Http\Requests\ResetPasswordRequest;
use App\Http\Responses\ApiResponse;
use App\Mail\PasswordResetCodeMail;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;
use Throwable;

use function Illuminate\Support\defer;

/** A50: password reset by a 6-digit code. No answer tells whether an email has an account. */
final class PasswordResetController
{
    public function __construct(private readonly PasswordResetService $resets) {}

    /** POST /auth/forgot-password -> 202, the same body for every email. */
    public function forgot(ForgotPasswordRequest $request): JsonResponse
    {
        $email = (string) $request->validated('email');
        $code = $this->resets->issue($email);
        if ($code !== null) {
            // After the response: no queue worker needed on the free host, and the answer's timing
            // does not depend on the mail server. defer() runs once per request (a terminating
            // callback would repeat in a long-lived process). The code is never queued or logged.
            defer(function () use ($email, $code): void {
                try {
                    Mail::to($email)->send(new PasswordResetCodeMail($code));
                } catch (Throwable $e) {
                    // Never the message: it could carry the address. Never the code.
                    Log::error('reset email failed', ['exception' => $e::class]);
                }
            });
        }

        return ApiResponse::success(['status' => 'requested'], 202);
    }

    /** POST /auth/reset-password -> 204; any invalid code or unknown email is one answer. */
    public function reset(ResetPasswordRequest $request): Response
    {
        $data = $request->validated();
        if (! $this->resets->reset((string) $data['email'], (string) $data['reset_token'], (string) $data['password'])) {
            throw ValidationException::withMessages(['reset_token' => ['This code is not valid. Request a new one.']]);
        }

        return response()->noContent();
    }
}
