<?php

use App\Exceptions\ApiExceptionRenderer;
use App\Http\Middleware\AssignRequestId;
use App\Http\Middleware\StrictTransportSecurity;
use App\Http\Middleware\TrustRenderProxy;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Support\Facades\Log;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        apiPrefix: 'api/v1',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->prepend(AssignRequestId::class);
        // A54: Render's proxy (client IP and scheme), and HSTS outside local and testing.
        $middleware->replace(TrustProxies::class, TrustRenderProxy::class);
        $middleware->append(StrictTransportSecurity::class);
        // API only: never redirect guests to a login page.
        $middleware->redirectGuestsTo(fn () => null);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->dontFlash(['password', 'password_confirmation', 'current_password', 'token', 'reset_token', 'push_token']);
        // A54, invariant 11: a database error's message carries its SQL and bindings (an email, a
        // token hash). Log only what kind of error it was.
        $exceptions->report(function (QueryException $e) {
            Log::error('database error', ['sql_state' => $e->errorInfo[0] ?? null, 'exception' => $e::class]);

            return false;
        });
        $exceptions->render(fn (Throwable $e) => (new ApiExceptionRenderer)($e));
    })->create();
