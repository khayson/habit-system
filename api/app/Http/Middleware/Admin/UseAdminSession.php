<?php

namespace App\Http\Middleware\Admin;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * A58: the admin page's session, set before StartSession: an encrypted cookie (no table, no
 * server state) scoped to /admin, HttpOnly, SameSite=Strict, and Secure outside local and tests.
 * The API never starts a session, so this changes nothing for the app.
 */
final class UseAdminSession
{
    public function handle(Request $request, Closure $next): Response
    {
        config([
            // Tests keep Laravel's in-memory store: the test client does not send cookies back.
            'session.driver' => app()->environment('testing') ? 'array' : 'cookie',
            'session.cookie' => 'habit_admin',
            'session.path' => '/admin',
            'session.http_only' => true,
            'session.same_site' => 'strict',
            'session.secure' => ! app()->environment('local', 'testing'),
            'session.expire_on_close' => true,
            'session.lifetime' => (int) config('admin.idle_minutes'),
            'session.encrypt' => true,
        ]);

        return $next($request);
    }
}
