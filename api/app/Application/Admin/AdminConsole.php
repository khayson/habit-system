<?php

namespace App\Application\Admin;

use App\Application\Accounts\AccountDeletionService;
use App\Domain\Clock;
use App\Models\User;
use App\Support\UtcTime;
use Carbon\CarbonImmutable;
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

    /**
     * @return array{rows: list<array{id: string, name: string, email: string, joined: string, status: string, devices: int}>, more: bool}
     */
    public function accounts(string $search, int $page): array
    {
        $query = DB::table('users')->orderByDesc('created_at');
        $search = trim($search);
        if ($search !== '') {
            $like = '%'.addcslashes(mb_strtolower($search), '%_\\').'%';
            $query->where(fn ($q) => $q->where('email', 'like', $like)->orWhereRaw('lower(name) like ?', [$like]));
        }
        $rows = $query->offset(max(0, $page - 1) * self::PAGE_SIZE)->limit(self::PAGE_SIZE + 1)->get();
        $devices = $this->deviceCounts(array_values(array_map(strval(...), $rows->pluck('id')->all())));

        return [
            'rows' => array_values($rows->take(self::PAGE_SIZE)->map(fn (stdClass $u) => [
                'id' => (string) $u->id,
                'name' => (string) $u->name,
                'email' => (string) $u->email,
                'joined' => UtcTime::format(CarbonImmutable::parse((string) $u->created_at)),
                'status' => $this->status($u),
                'devices' => $devices[$u->id] ?? 0,
            ])->all()),
            'more' => $rows->count() > self::PAGE_SIZE,
        ];
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
            ->map(fn (stdClass $a) => [
                'action' => (string) $a->action,
                'subject' => $a->subject === null ? null : (string) $a->subject,
                'detail' => (string) $a->detail === '{}' || (string) $a->detail === '[]' ? '' : (string) $a->detail,
                'at' => UtcTime::format(CarbonImmutable::parse((string) $a->created_at)),
            ])->all());
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

    /**
     * @param  list<string>  $ids
     * @return array<string, int>
     */
    private function deviceCounts(array $ids): array
    {
        if ($ids === []) {
            return [];
        }

        return DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
            ->whereIn('tokenable_id', $ids)->selectRaw('tokenable_id, count(*) as n')->groupBy('tokenable_id')
            ->pluck('n', 'tokenable_id')->map(fn ($n) => (int) $n)->all();
    }
}
