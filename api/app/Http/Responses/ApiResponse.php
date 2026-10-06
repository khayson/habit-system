<?php

namespace App\Http\Responses;

use App\Http\RequestContext;
use Illuminate\Http\JsonResponse;

/**
 * Builds the spec envelopes:
 *   success: { data, meta: { api_version, server_time, request_id, ...extra } }
 *   error:   { error: { code, message, ...extra }, meta: { request_id, server_time } }
 */
final class ApiResponse
{
    public const string API_VERSION = 'v1';

    private const int JSON_FLAGS = JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE;

    /**
     * @param  array<string, mixed>  $meta  extra meta keys (e.g. duplicate, reward_delta)
     * @param  array<string, string>  $headers
     */
    public static function success(mixed $data, int $status = 200, array $meta = [], array $headers = []): JsonResponse
    {
        $context = app(RequestContext::class);

        return new JsonResponse([
            'data' => $data,
            'meta' => [
                'api_version' => self::API_VERSION,
                'server_time' => $context->serverTime(),
                'request_id' => $context->requestId(),
                ...$meta,
            ],
        ], $status, $headers, self::JSON_FLAGS);
    }

    /**
     * @param  array<string, mixed>  $extra  additional error keys (fields, resource_id, current, ...)
     * @param  array<string, string>  $headers
     */
    public static function error(int $status, string $code, string $message, array $extra = [], array $headers = []): JsonResponse
    {
        $context = app(RequestContext::class);

        return new JsonResponse([
            'error' => [
                'code' => $code,
                'message' => $message,
                ...$extra,
            ],
            'meta' => [
                'request_id' => $context->requestId(),
                'server_time' => $context->serverTime(),
            ],
        ], $status, $headers, self::JSON_FLAGS);
    }
}
