<?php

namespace App\Http\Middleware;

use App\Domain\Clock;
use App\Http\RequestContext;
use Closure;
use Illuminate\Contracts\Foundation\Application;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpFoundation\Response;

/**
 * Global (first) middleware: gives each request a fresh RequestContext, puts request_id on log
 * lines and X-Request-Id on the response. The id is always server-generated; a client-supplied
 * X-Request-Id is ignored.
 */
final class AssignRequestId
{
    public function __construct(
        private readonly Application $app,
        private readonly Clock $clock,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $context = new RequestContext($this->clock);
        $this->app->instance(RequestContext::class, $context);
        Log::withContext(['request_id' => $context->requestId()]);

        /** @var Response $response */
        $response = $next($request);
        $response->headers->set('X-Request-Id', $context->requestId());

        return $response;
    }
}
