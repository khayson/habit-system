<?php

namespace App\Application\Ops;

use App\Domain\Clock;
use Illuminate\Support\Facades\DB;

/**
 * A55: whether the system is healthy, in numbers only. No id, name, email, habit name, note or
 * token ever leaves this class; every value is a count, a size or a time.
 */
final readonly class OpsStatus
{
    public function __construct(private Clock $clock, private OpsMetrics $metrics) {}

    /**
     * @return array{
     *     accounts: array{live: int, deletions_pending: int},
     *     check_ins_last_24h: int,
     *     queue: array{waiting: int, oldest_waiting_seconds: ?int, failed: int},
     *     last_tick_at: ?string,
     *     mail_failures: array{last_7_days: int, last_at: ?string},
     *     database: array{size_bytes: int, limit_bytes: int, used_percent: float},
     *     min_app_version: int
     * }
     */
    public function collect(): array
    {
        $now = $this->clock->now()->utc();
        $oldest = DB::table('jobs')->min('created_at');
        $size = (int) (DB::selectOne('SELECT pg_database_size(current_database()) AS bytes')->bytes ?? 0);
        $limit = config()->integer('api.ops_db_limit_bytes');

        return [
            'accounts' => [
                'live' => DB::table('users')->whereNull('deleted_at')->count(),
                'deletions_pending' => DB::table('account_deletions')->where('status', '!=', 'completed')->count(),
            ],
            // A rolling window: no day boundary to compute (R4, invariant 15).
            'check_ins_last_24h' => DB::table('habit_logs')->whereNull('deleted_at')
                ->where('created_at', '>=', $now->subDay()->toDateTimeString().'+00')->count(),
            'queue' => [
                'waiting' => DB::table('jobs')->count(),
                'oldest_waiting_seconds' => $oldest === null ? null : max(0, $now->getTimestamp() - (int) $oldest),
                'failed' => DB::table('failed_jobs')->count(),
            ],
            'last_tick_at' => $this->metrics->lastTickAt(),
            'mail_failures' => $this->metrics->mailFailures($now),
            'database' => [
                'size_bytes' => $size,
                'limit_bytes' => $limit,
                'used_percent' => $limit > 0 ? round($size * 100 / $limit, 1) : 0.0,
            ],
            'min_app_version' => config()->integer('api.min_app_version'),
        ];
    }
}
