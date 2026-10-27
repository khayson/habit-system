<?php

namespace App\Http\Controllers\Admin;

use App\Application\Admin\AdminAuth;
use App\Application\Admin\AdminConsole;
use App\Application\Admin\AdminStats;
use App\Application\Notices\NoticeBoard;
use App\Application\Ops\OpsStatus;
use App\Application\Ops\Ticker;
use App\Domain\Clock;
use App\Support\UtcTime;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\RateLimiter;
use InvalidArgumentException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

/**
 * A58: Khay Studios' admin page. Thin: AdminAuth signs in, AdminConsole reads and changes
 * accounts (never their habit data), NoticeBoard publishes, Ticker runs the timer. Every change
 * appends to the audit.
 */
final readonly class AdminController
{
    public function __construct(
        private AdminAuth $auth,
        private AdminConsole $console,
        private Clock $clock,
    ) {}

    public function loginForm(): View
    {
        $this->ensureConfigured();

        return view('admin.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $this->ensureConfigured();
        $key = 'admin-login:'.$request->ip();
        if (RateLimiter::tooManyAttempts($key, (int) config('admin.login_per_minute'))) {
            return back()->withErrors(['login' => 'Too many tries. Wait a minute, then try again.']);
        }
        RateLimiter::hit($key, 60);
        $ok = $this->auth->attempt(
            (string) $request->input('email', ''),
            (string) $request->input('password', ''),
            (string) $request->input('code', ''),
        );
        if (! $ok) {
            return back()->withErrors(['login' => 'Those details did not work.'])->onlyInput('email');
        }
        RateLimiter::clear($key);
        $request->session()->regenerate();
        $now = $this->clock->now()->getTimestamp();
        $request->session()->put(['admin.since' => $now, 'admin.seen' => $now]);
        $this->console->audit('admin.sign_in');

        return redirect('/admin');
    }

    public function logout(Request $request): RedirectResponse
    {
        $this->console->audit('admin.sign_out');
        $request->session()->invalidate();

        return redirect('/admin/login');
    }

    public function dashboard(OpsStatus $status, AdminStats $stats): View
    {
        return view('admin.dashboard', [
            's' => $status->collect(),
            'kpi' => $stats->kpis(),
            'series' => $stats->series(),
            'actions' => $this->console->recentActions(8),
        ]);
    }

    public function health(OpsStatus $status, AdminStats $stats): View
    {
        return view('admin.health', ['s' => $status->collect(), 'jobs' => $stats->jobs()]);
    }

    public function retryJob(AdminStats $stats, string $uuid): RedirectResponse
    {
        $ok = $stats->retryFailed($uuid);
        if ($ok) {
            $this->console->audit('server.retry_job', $uuid);
        }

        return back()->with('status', $ok ? 'Queued again; the next tick runs it.' : 'That job is no longer in the failed list.');
    }

    public function forgetJob(AdminStats $stats, string $uuid): RedirectResponse
    {
        $ok = $stats->forgetFailed($uuid);
        if ($ok) {
            $this->console->audit('server.forget_job', $uuid);
        }

        return back()->with('status', $ok ? 'Removed from the failed list.' : 'That job is no longer in the failed list.');
    }

    public function forgetAllJobs(AdminStats $stats): RedirectResponse
    {
        $count = $stats->forgetAllFailed();
        $this->console->audit('server.forget_failed_jobs', null, ['count' => $count]);

        return back()->with('status', "Cleared {$count} failed jobs.");
    }

    public function activity(Request $request): View
    {
        $page = max(1, (int) $request->query('page', '1'));
        $filters = [
            'action' => (string) $request->query('action', ''),
            'from' => (string) $request->query('from', ''),
            'to' => (string) $request->query('to', ''),
        ];

        return view('admin.activity', [
            ...$this->console->actions($filters['action'], $filters['from'], $filters['to'], $page),
            'filters' => $filters,
            'page' => $page,
        ]);
    }

    public function runTick(Ticker $ticker): RedirectResponse
    {
        $ran = $ticker->run();
        $this->console->audit('server.tick', null, ['ran' => $ran]);

        return back()->with('status', $ran ? 'The timer ran.' : 'A tick is already running; nothing was started.');
    }

    public function retryJobs(): RedirectResponse
    {
        Artisan::call('queue:retry', ['id' => ['all']]);
        $this->console->audit('server.retry_failed_jobs');

        return back()->with('status', 'Failed jobs are queued again; the next tick runs them.');
    }

    public function accounts(Request $request): View
    {
        $page = max(1, (int) $request->query('page', '1'));
        $search = (string) $request->query('q', '');
        $status = in_array($request->query('status'), AdminConsole::STATUSES, true) ? (string) $request->query('status') : 'all';
        $sort = in_array($request->query('sort'), AdminConsole::SORTS, true) ? (string) $request->query('sort') : 'newest';

        return view('admin.accounts', [
            ...$this->console->accounts($search, $page, $status, $sort),
            'q' => $search, 'page' => $page, 'status' => $status, 'sort' => $sort,
        ]);
    }

    public function account(string $id): View
    {
        $account = $this->console->account($id) ?? throw new NotFoundHttpException;

        return view('admin.account', ['a' => $account]);
    }

    public function signOut(string $id): RedirectResponse
    {
        return $this->done($this->console->signOut($id), 'Signed out of every device.');
    }

    public function suspend(string $id): RedirectResponse
    {
        return $this->done($this->console->suspend($id), 'Suspended and signed out. Sign-in is refused until you resume.');
    }

    public function resume(string $id): RedirectResponse
    {
        return $this->done($this->console->resume($id), 'Resumed. They can sign in again.');
    }

    public function delete(Request $request, string $id): RedirectResponse
    {
        if (! $this->console->delete($id, (string) $request->input('confirm_email', ''))) {
            return back()->withErrors(['delete' => 'Type the account\'s email exactly to delete it.']);
        }

        return redirect('/admin/accounts')->with('status', 'Deletion started; the account is purged within 30 days.');
    }

    public function notices(NoticeBoard $board, Request $request): View
    {
        return view('admin.notices', [
            'notices' => $board->all(),
            'to' => (string) $request->query('to', ''),
            'now' => UtcTime::format($this->clock->now()),
        ]);
    }

    public function publishNotice(Request $request, NoticeBoard $board): RedirectResponse
    {
        $to = array_values(array_filter(array_map('trim', preg_split('/[\s,;]+/', (string) $request->input('to', '')) ?: [])));
        $ends = trim((string) $request->input('ends', ''));
        try {
            $id = $board->publish(
                (string) $request->input('title', ''),
                (string) $request->input('body', ''),
                null,
                $ends === '' ? null : $this->utcFromForm($ends),
                $to,
            );
        } catch (InvalidArgumentException $e) {
            return back()->withErrors(['notice' => $e->getMessage()])->withInput();
        }
        $this->console->audit('notice.publish', $id, ['people' => count($to)]);

        return redirect('/admin/notices')->with('status', $to === [] ? 'Published to everyone.' : 'Published to '.count($to).' people.');
    }

    public function retireNotice(NoticeBoard $board, string $id): RedirectResponse
    {
        $ok = $board->retire($id);
        if ($ok) {
            $this->console->audit('notice.retire', $id);
        }

        return back()->with('status', $ok ? 'Retired.' : 'That notice had already ended.');
    }

    private function done(bool $ok, string $message): RedirectResponse
    {
        if (! $ok) {
            throw new NotFoundHttpException;
        }

        return back()->with('status', $message);
    }

    private function ensureConfigured(): void
    {
        if (! $this->auth->configured()) {
            throw new NotFoundHttpException;
        }
    }

    /** The form's end, "YYYY-MM-DD HH:MM" in UTC (or the browser's datetime-local), as ISO-8601. */
    private function utcFromForm(string $value): string
    {
        if (! preg_match('/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2})$/', $value, $m)) {
            throw new InvalidArgumentException('Write the end as YYYY-MM-DD HH:MM (UTC).');
        }

        return "{$m[1]}T{$m[2]}:00Z";
    }
}
