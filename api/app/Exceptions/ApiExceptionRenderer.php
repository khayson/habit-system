<?php

namespace App\Exceptions;

use App\Http\Responses\ApiResponse;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;

/**
 * Maps every exception to the spec error envelope. This app is API-only, so it applies to all
 * requests. Messages are fixed strings: exception text, traces and SQL never reach the client.
 *
 * Runs after Laravel's prepareException(), so ModelNotFound / RecordsNotFound arrive as 404
 * and AuthorizationException as 403 HttpExceptions.
 */
final class ApiExceptionRenderer
{
    // Every code is contract: docs/api-error-codes.md, one fixture each in contract-fixtures/envelope/.
    private const array HTTP_CODES = [
        400 => ['bad_request', 'The request could not be read.'],
        401 => ['unauthenticated', 'Sign in to continue.'],
        403 => ['forbidden', 'This action is not allowed.'],
        404 => ['not_found', 'Not found.'],
        405 => ['method_not_allowed', 'This method is not supported here.'],
        413 => ['payload_too_large', 'This request is too large.'],
        415 => ['unsupported_media_type', 'Send JSON.'],
        429 => ['rate_limited', 'Too many requests. Try again shortly.'],
        503 => ['unavailable', 'The service is briefly unavailable. Try again shortly.'],
    ];

    private const array SERVER_ERROR = ['server_error', 'Something went wrong. Try again.'];

    /** Headers a client needs to act on an error; anything else an exception carries is dropped. */
    private const array FORWARDED_HEADERS = ['Retry-After', 'Allow'];

    public function __invoke(Throwable $e): ?JsonResponse
    {
        return match (true) {
            $e instanceof HttpResponseException => null,
            $e instanceof ApiException => ApiResponse::error($e->status, $e->errorCode, $e->getMessage(), $e->extra, $e->headers),
            $e instanceof ValidationException => ApiResponse::error(422, 'validation_failed', 'Check the highlighted fields.', [
                'fields' => $e->errors(),
            ]),
            $e instanceof AuthenticationException => self::http(401),
            $e instanceof HttpExceptionInterface => self::http($e->getStatusCode(), $e->getHeaders()),
            default => ApiResponse::error(500, ...self::SERVER_ERROR),
        };
    }

    /**
     * @param  array<string, mixed>  $headers
     */
    private static function http(int $status, array $headers = []): JsonResponse
    {
        [$code, $message] = self::HTTP_CODES[$status]
            ?? ($status >= 500 ? self::SERVER_ERROR : ['http_error', 'The request could not be completed.']);

        $forward = [];
        foreach (self::FORWARDED_HEADERS as $name) {
            if (isset($headers[$name]) && is_scalar($headers[$name])) {
                $forward[$name] = (string) $headers[$name];
            }
        }

        return ApiResponse::error($status, $code, $message, [], $forward);
    }
}
