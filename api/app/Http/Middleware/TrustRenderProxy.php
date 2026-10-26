<?php

namespace App\Http\Middleware;

use Illuminate\Http\Middleware\TrustProxies;

/**
 * A54: the service is reachable only through Render's proxy, whose addresses are not fixed, so
 * the proxies come from config (TRUSTED_PROXIES, default "*"; empty trusts none). Then
 * request()->ip() is the client's address and the scheme is the one the client used.
 */
final class TrustRenderProxy extends TrustProxies
{
    protected function proxies()
    {
        $proxies = trim(config()->string('api.trusted_proxies'));

        return match ($proxies) {
            '' => null,
            '*' => '*',
            default => array_map('trim', explode(',', $proxies)),
        };
    }
}
