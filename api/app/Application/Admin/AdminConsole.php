<?php

namespace App\Application\Admin;

use App\Application\Accounts\AccountDeletionService;
use App\Domain\Clock;
use App\Models\User;
use App\Support\UtcTime;
use Carbon\CarbonImmutable;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use stdClass;

/**
 * A58: what the admin page reads and does to accounts. Account details only (name, email,
 * timezone, sign-up date, status, devices); never habits, logs, notes, rewards, photos or
 * exports. Every action appends to admin_actions.
 */
final readonly class AdminConsole
{
    public const int PAGE_SIZE = 25;

    public function __construct(private Clock $clock, private AccountDeletionService $deletions) {}

    public const array STATUSES = ['all', 'active', 'suspended', 'deletion'];

    public const array SORTS = ['newest', 'oldest', 'last_active', 'email'];

    /**
     * One page of accounts, filtered by [$status] and ordered by [$sort]. Last active is the
     * latest use of any of the account's sign-ins.
     *
     * @return array{rows: list<array{id: string, name: string, email: string, joined: string, last_active: string|null, status: string, devices: int}>, more: bool, counts: array<string, int>}
     */
    public function accounts(string $search, int $page, string $status = 'all', string $sort = 'newest'): array
    {
        $tokens = DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
            ->selectRaw('tokenable_id, max(last_used_at) as last_active, count(*) as devices')->groupBy('tokenable_id');
        $query = DB::table('users')->leftJoinSub($tokens, 't', 't.tokenable_id', '=', 'users.id')
            ->select('users.*', 't.last_active', 't.devices');
        $search = trim($search);
        if ($search !== '') {
            $like = '%'.addcslashes(mb_strtolower($search), '%_\\').'%';
            $query->where(fn ($q) => $q->where('users.email', 'like', $like)->orWhereRaw('lower(users.name) like ?', [$like]));
        }
        $this->whereStatus($query, $status);
        match ($sort) {
            'oldest' => $query->orderBy('users.created_at'),
            'last_active' => $query->orderByRaw('t.last_active desc nulls last'),
            'email' => $query->orderBy('users.email'),
            default => $query->orderByDesc('users.created_at'),
        };
        $rows = $query->orderBy('users.id')->offset(max(0, $page - 1) * self::PAGE_SIZE)->limit(self::PAGE_SIZE + 1)->get();

        return [
            'rows' => array_values($rows->take(self::PAGE_SIZE)->map(fn (stdClass $u) => [
                'id' => (string) $u->id,
                'name' => (string) $u->name,
                'email' => (string) $u->email,
                'joined' => UtcTime::format(CarbonImmutable::parse((string) $u->created_at)),
                'last_active' => $u->last_active === null ? null : UtcTime::format(CarbonImmutable::parse((string) $u->last_active)),
                'status' => $this->status($u),
                'devices' => (int) ($u->devices ?? 0),
            ])->all()),
            'more' => $rows->count() > self::PAGE_SIZE,
            'counts' => array_combine(self::STATUSES, array_map(function (string $s) {
                $q = DB::table('users');
                $this->whereStatus($q, $s);

                return $q->count();
            }, self::STATUSES)),
        ];
    }

    /**
     * The audit, newest first, optionally one action and a UTC date range (inclusive dates).
     *
     * @return array{rows: list<array{action: string, subject: string|null, detail: string, at: string}>, more: bool, actions: list<string>}
     */
    public function actions(string $action, string $from, string $to, int $page): array
    {
        $query = DB::table('admin_actions');
        if ($action !== '') {
            $query->where('action', $action);
        }
        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $from)) {
            $query->where('created_at', '>=', "{$from} 00:00:00+00");
        }
        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $to)) {
            $query->whereRaw("created_at < (?::date + 1)::timestamp at time zone 'UTC'", [$to]);
        }
        $rows = $query->orderByDesc('created_at')->orderByDesc('id')
            ->offset(max(0, $page - 1) * 50)->limit(51)->get();

        return [
            'rows' => array_values($rows->take(50)->map(fn (stdClass $a) => $this->presentAction($a))->all()),
            'more' => $rows->count() > 50,
            'actions' => array_values(array_map(strval(...), DB::table('admin_actions')->distinct()->orderBy('action')->pluck('action')->all())),
        ];
    }

    /** @param Builder $query */
    private function whereStatus($query, string $status): void
    {
        match ($status) {
            'active' => $query->whereNull('users.deleted_at')->whereNull('users.suspended_at'),
            'suspended' => $query->whereNull('users.deleted_at')->whereNotNull('users.suspended_at'),
            'deletion' => $query->whereNotNull('users.deleted_at'),
            default => null,
        };
    }

    /**
     * @return array{id: string, name: string, email: string, timezone: string, joined: string, status: string, devices: list<array{name: string, last_used: string|null, since: string}>}|null
     */
    public function account(string $id): ?array
    {
        if (! Str::isUuid($id)) {
            return null;
        }
        $u = DB::table('users')->where('id', $id)->first();
        if ($u === null) {
            return null;
        }
        $devices = DB::table('personal_access_tokens')
            ->where('tokenable_type', (new User)->getMorphClass())->where('tokenable_id', $id)
            ->orderByDesc('last_used_at')->get(['name', 'last_used_at', 'created_at']);

        return [
            'id' => (string) $u->id,
            'name' => (string) $u->name,
            'email' => (string) $u->email,
            'timezone' => (string) ($u->timezone ?? ''),
            'joined' => UtcTime::format(CarbonImmutable::parse((string) $u->created_at)),
            'status' => $this->status($u),
            'devices' => array_values($devices->map(fn (stdClass $d) => [
                'name' => (string) $d->name,
                'last_used' => $d->last_used_at === null ? null : UtcTime::format(CarbonImmutable::parse((string) $d->last_used_at)),
                'since' => UtcTime::format(CarbonImmutable::parse((string) $d->created_at)),
            ])->all()),
        ];
    }

    /** Signs the account out everywhere; its data is untouched. */
    public function signOut(string $id): bool
    {
        if ($this->live($id) === null) {
            return false;
        }
        $count = $this->revokeTokens($id);
        $this->audit('account.sign_out', $id, ['devices' => $count]);

        return true;
    }

    /** Refuses sign-in until resumed, and signs the account out now. */
    public function suspend(string $id): bool
    {
        if ($this->live($id) === null) {
            return false;
        }
        DB::transaction(function () use ($id) {
            DB::table('users')->where('id', $id)->update(['suspended_at' => UtcTime::format($this->clock->now())]);
            $this->revokeTokens($id);
            $this->audit('account.suspend', $id);
        });

        return true;
    }

    public function resume(string $id): bool
    {
        if ($this->live($id) === null) {
            return false;
        }
        DB::table('users')->where('id', $id)->update(['suspended_at' => null]);
        $this->audit('account.resume', $id);

        return true;
    }

    /** A49's deletion, confirmed by typing the account's email. */
    public function delete(string $id, string $typedEmail): bool
    {
        $user = $this->live($id);
        if ($user === null || ! hash_equals((string) $user->email, mb_strtolower(trim($typedEmail)))) {
            return false;
        }
        $this->deletions->delete($id);
        $this->audit('account.delete', $id);

        return true;
    }

    /**
     * Appends to the audit. [$detail] is small and never holds a secret or an IP address.
     *
     * @param  array<string, scalar|null>  $detail
     */
    public function audit(string $action, ?string $subject = null, array $detail = []): void
    {
        DB::table('admin_actions')->insert([
            'id' => (string) Str::uuid7(),
            'action' => $action,
            'subject' => $subject,
            'detail' => json_encode((object) $detail, JSON_THROW_ON_ERROR),
            'created_at' => UtcTime::format($this->clock->now()),
        ]);
    }

    /**
     * @return list<array{action: string, subject: string|null, detail: string, at: string}>
     */
    public function recentActions(int $limit = 20): array
    {
        return array_values(DB::table('admin_actions')->orderByDesc('created_at')->orderByDesc('id')->limit($limit)->get()
            ->map(fn (stdClass $a) => $this->presentAction($a))->all());
    }

    /** @return array{action: string, subject: string|null, detail: string, at: string} */
    private function presentAction(stdClass $a): array
    {
        return [
            'action' => (string) $a->action,
            'subject' => $a->subject === null ? null : (string) $a->subject,
            'detail' => (string) $a->detail === '{}' || (string) $a->detail === '[]' ? '' : (string) $a->detail,
            'at' => UtcTime::format(CarbonImmutable::parse((string) $a->created_at)),
        ];
    }

    /** An account not deleted (purge pending accounts are not managed here). */
    private function live(string $id): ?stdClass
    {
        if (! Str::isUuid($id)) {
            return null;
        }

        return DB::table('users')->where('id', $id)->whereNull('deleted_at')->first();
    }

    private function revokeTokens(string $id): int
    {
        return DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
            ->where('tokenable_id', $id)->delete();
    }

    private function status(stdClass $user): string
    {
        return match (true) {
            $user->deleted_at !== null => 'deletion pending',
            $user->suspended_at !== null => 'suspended',
            default => 'active',
        };
    }
}
