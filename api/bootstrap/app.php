<?php

use App\Exceptions\ApiExceptionRenderer;
use App\Http\Middleware\Admin\AdminSecurityHeaders;
use App\Http\Middleware\Admin\UseAdminSession;
use App\Http\Middleware\AssignRequestId;
use App\Http\Middleware\StrictTransportSecurity;
use App\Http\Middleware\TrustRenderProxy;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Middleware\TrustProxies;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        // A58: the admin page; the only web routes.
        web: __DIR__.'/../routes/admin.php',
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
        // A58: the web group serves /admin and the A59 email links: a cookie session, strict headers.
        $middleware->web(prepend: [UseAdminSession::class], append: [AdminSecurityHeaders::class]);
        // A59: mail apps' one-click unsubscribe POSTs carry no CSRF token; the URL is signed.
        $middleware->preventRequestForgery(except: ['emails/stop/*']);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->dontFlash(['password', 'password_confirmation', 'current_password', 'token', 'reset_token', 'push_token']);
        // A54, invariant 11: a database error's message carries its SQL and bindings (an email, a
        // token hash). Log only what kind of error it was.
        $exceptions->report(function (QueryException $e) {
            Log::error('database error', ['sql_state' => $e->errorInfo[0] ?? null, 'exception' => $e::class]);

            return false;
        });
        // A58: the admin pages keep Laravel's own HTML handling (redirect back with errors);
        // everything else is the API's JSON envelope.
        $exceptions->render(fn (Throwable $e, Request $request) => $request->is('admin', 'admin/*', 'emails/*') ? null : (new ApiExceptionRenderer)($e));
    })->create();
