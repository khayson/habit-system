<?php

namespace App\Http;

use App\Domain\Clock;
use App\Support\UtcTime;
use Illuminate\Support\Str;

/**
 * Per-request identity and server time. Scoped to one request; values are created lazily so
 * errors raised before routing (unknown route, oversized body) still carry them.
 */
final class RequestContext
{
    private ?string $requestId = null;

    private ?string $serverTime = null;

    public function __construct(private readonly Clock $clock) {}

    public function requestId(): string
    {
        return $this->requestId ??= (string) Str::uuid7();
    }

    public function serverTime(): string
    {
        return $this->serverTime ??= UtcTime::format($this->clock->now());
    }
}
