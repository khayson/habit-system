<?php

namespace App\Http\Middleware\Admin;

use App\Application\Admin\AdminAuth;
use App\Domain\Clock;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * A58: every admin page but sign-in. Not configured: a plain 404, so the page is never
 * advertised. Not signed in, idle past the limit, or past the absolute limit: back to sign-in.
 */
final readonly class EnsureAdmin
{
    public function __construct(private AdminAuth $auth, private Clock $clock) {}

    public function handle(Request $request, Closure $next): Response
    {
        if (! $this->auth->configured()) {
            throw new NotFoundHttpException;
        }
        $session = $request->session();
        $now = $this->clock->now()->getTimestamp();
        $since = $session->get('admin.since');
        $seen = $session->get('admin.seen');
        $fresh = is_int($since) && is_int($seen)
            && $now - $seen <= 60 * (int) config('admin.idle_minutes')
            && $now - $since <= 60 * (int) config('admin.absolute_minutes');
        if (! $fresh) {
            $session->invalidate();

            return redirect('/admin/login');
        }
        $session->put('admin.seen', $now);

        return $next($request);
    }
}
