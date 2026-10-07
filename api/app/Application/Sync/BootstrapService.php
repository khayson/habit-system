<?php

namespace App\Application\Sync;

use App\Application\Presenters\EntityPresenter;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use stdClass;

/**
 * GET /sync/bootstrap (A2): a paged snapshot for a fresh install, a new device or after 410.
 * The first page pins snapshot_seq; pages read live rows, so a row may be newer than the snapshot.
 * That is safe: the client then calls /sync from snapshot_seq and replays idempotently (a change
 * applies only if its version is >= the local one).
 *
 * Pages: user (first page only) → habits (with definitions and ranges) → logs, including
 * tombstones so deletions reconcile.
 */
final readonly class BootstrapService
{
    public const int DEFAULT_LIMIT = 200;

    public const int MAX_LIMIT = 500;

    private const string PHASE_HABITS = 'habits';

    private const string PHASE_LOGS = 'logs';

    public function __construct(private EntityPresenter $presenter) {}

    /** @return array<string, mixed> */
    public function page(string $userId, ?string $cursor, int $limit): array
    {
        if ($cursor === null) {
            $state = ['snap' => (int) DB::table('users')->where('id', $userId)->value('change_seq'), 'phase' => self::PHASE_HABITS, 'after' => null];
            $first = true;
        } else {
            $state = SyncCursor::decode($cursor, $userId, 'b')
                ?? throw ValidationException::withMessages(['cursor' => ['The cursor is not valid for this account.']]);
            $first = false;
        }

        $user = $first ? $this->presenter->user(DB::table('users')->where('id', $userId)->first() ?? (object) []) : null;
        $habits = [];
        $logs = [];
        $next = null;

        if ($state['phase'] === self::PHASE_HABITS) {
            $rows = DB::table('habits')->where('user_id', $userId)
                ->when($state['after'] !== null, fn ($q) => $q->where('id', '>', $state['after']))
                ->orderBy('id')->limit($limit + 1)->get();
            $habits = $rows->take($limit)->map(fn (stdClass $h) => $this->presenter->habit($h))->values()->all();
            $next = $rows->count() > $limit
                ? ['phase' => self::PHASE_HABITS, 'after' => (string) $rows->get($limit - 1)?->id]
                : ['phase' => self::PHASE_LOGS, 'after' => null];
        } else {
            $rows = DB::table('habit_logs')
                ->join('habits', 'habits.id', '=', 'habit_logs.habit_id')
                ->where('habit_logs.user_id', $userId)
                ->when($state['after'] !== null, fn ($q) => $q->where('habit_logs.id', '>', $state['after']))
                ->orderBy('habit_logs.id')->limit($limit + 1)
                ->get(['habit_logs.*', 'habits.type as habit_type']);
            $logs = $rows->take($limit)->map(fn (stdClass $l) => $this->presenter->log($l, (string) $l->habit_type))->values()->all();
            $next = $rows->count() > $limit ? ['phase' => self::PHASE_LOGS, 'after' => (string) $rows->get($limit - 1)?->id] : null;
        }

        $snap = (int) $state['snap'];

        return [
            'user' => $user,
            'habits' => $habits,
            'logs' => $logs,
            'has_more' => $next !== null,
            'next_cursor' => $next === null ? null : SyncCursor::encode($userId, 'b', ['snap' => $snap, ...$next]),
            // Only on the last page: continue with POST /sync from here.
            'sync_cursor' => $next === null ? SyncCursor::forSeq($userId, $snap) : null,
            'snapshot_seq' => $snap,
        ];
    }
}
