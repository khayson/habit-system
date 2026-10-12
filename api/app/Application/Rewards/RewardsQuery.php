<?php

namespace App\Application\Rewards;

use App\Application\Presenters\EntityPresenter;
use App\Application\Sync\SyncCursor;
use App\Domain\Freeze\FreezeEvaluator;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * GET /rewards and GET /freezes (A39 to A42): the cached numbers and their ledgers, newest first,
 * keyset-paged on (created_at, id) with an opaque cursor bound to the user. Read-only and
 * owner-scoped (invariant 2); the numbers are the same ones reward_state carries.
 */
final readonly class RewardsQuery
{
    public const int DEFAULT_LIMIT = 20;

    public const int MAX_LIMIT = 50;

    /** The opt-in history shown with the wallet. */
    public const int POLICY_LIMIT = 20;

    public function __construct(private EntityPresenter $presenter) {}

    /** @return array<string, mixed> */
    public function rewards(string $userId, ?string $cursor, int $limit): array
    {
        $user = DB::table('users')->where('id', $userId)->first(['xp', 'freeze_balance']) ?? (object) ['xp' => 0, 'freeze_balance' => 0];
        $state = $this->presenter->rewardState($user);
        $query = DB::table('xp_ledger as l')->join('xp_entitlements as e', 'e.id', '=', 'l.entitlement_id')
            ->where('l.user_id', $userId)
            ->select(['l.id', 'l.delta', 'l.reason', 'e.habit_id', 'e.log_date', 'l.created_at']);
        [$rows, $next] = $this->page($query, $userId, 'xp', $cursor, $limit);

        return [
            'xp' => $state['xp'],
            'level' => $state['level'],
            'progress_into_level' => $state['progress_into_level'],
            'next_level_threshold' => $state['next_level_threshold'],
            'ledger' => array_map(fn ($r) => [
                'id' => (string) $r->id,
                'delta' => (int) $r->delta,
                'reason' => (string) $r->reason,
                'habit_id' => (string) $r->habit_id,
                'log_date' => (string) $r->log_date,
                'created_at' => UtcTime::format(WireTime::parse((string) $r->created_at)),
            ], $rows),
            'next_cursor' => $next,
        ];
    }

    /** @return array<string, mixed> */
    public function freezes(string $userId, ?string $cursor, int $limit): array
    {
        $user = DB::table('users')->where('id', $userId)->first(['freeze_balance', 'auto_freeze']) ?? (object) ['freeze_balance' => 0, 'auto_freeze' => false];
        // A spend or refund row names its usage; a grant has none.
        $query = DB::table('freeze_ledger as l')
            ->leftJoin('freeze_usage as u', fn ($j) => $j->on('u.spend_ledger_id', '=', 'l.id')->orOn('u.refund_ledger_id', '=', 'l.id'))
            ->where('l.user_id', $userId)
            ->select(['l.id', 'l.kind', 'l.delta', 'l.reason', 'u.habit_id', 'u.period_key', 'l.created_at']);
        [$rows, $next] = $this->page($query, $userId, 'fz', $cursor, $limit);
        $policy = DB::table('user_freeze_policy_versions')->where('user_id', $userId)
            ->orderByDesc('effective_at')->orderByDesc('id')->limit(self::POLICY_LIMIT)->get(['enabled', 'effective_at']);

        return [
            'freeze_balance' => (int) $user->freeze_balance,
            'cap' => FreezeEvaluator::CAP,
            'auto_freeze' => (bool) $user->auto_freeze,
            'policy' => $policy->map(fn ($p) => [
                'enabled' => (bool) $p->enabled,
                'effective_at' => UtcTime::format(WireTime::parse((string) $p->effective_at)),
            ])->values()->all(),
            'ledger' => array_map(fn ($r) => [
                'id' => (string) $r->id,
                'kind' => (string) $r->kind,
                'delta' => (int) $r->delta,
                'reason' => (string) $r->reason,
                'habit_id' => $r->habit_id === null ? null : (string) $r->habit_id,
                'period_key' => $r->period_key === null ? null : (string) $r->period_key,
                'created_at' => UtcTime::format(WireTime::parse((string) $r->created_at)),
            ], $rows),
            'next_cursor' => $next,
        ];
    }

    /**
     * One page newest first. The cursor carries the last row's exact (created_at, id).
     *
     * @return array{list<\stdClass>, ?string}
     */
    private function page(Builder $query, string $userId, string $type, ?string $cursor, int $limit): array
    {
        if ($cursor !== null) {
            $state = SyncCursor::decode($cursor, $userId, $type);
            if (! is_string($state['at'] ?? null) || ! is_string($state['id'] ?? null)) {
                throw ValidationException::withMessages(['cursor' => ['This cursor is not valid.']]);
            }
            $query->whereRaw('(l.created_at, l.id) < (?::timestamptz, ?::uuid)', [$state['at'], $state['id']]);
        }
        $rows = array_values($query->orderByDesc('l.created_at')->orderByDesc('l.id')->limit($limit + 1)->get()->all());
        $next = null;
        if (count($rows) > $limit) {
            $rows = array_slice($rows, 0, $limit);
            $last = $rows[$limit - 1];
            $next = SyncCursor::encode($userId, $type, ['at' => (string) $last->created_at, 'id' => (string) $last->id]);
        }

        return [$rows, $next];
    }
}
