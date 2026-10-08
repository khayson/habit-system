<?php

namespace App\Console\Commands;

use App\Application\Periods\PeriodCloser;
use App\Jobs\ClosePeriodsJob;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * A10 scheduler entry (every 5 minutes): one unique job per user whose next local day boundary
 * has passed (watermark: habit_streak_cache.computed_through) or whose calendar changed.
 */
final class ClosePeriods extends Command
{
    protected $signature = 'habits:close-periods {--sync : run each user inline instead of queueing}';

    protected $description = 'Close finished periods and refresh streaks for users whose watermark is stale (A10).';

    public function handle(PeriodCloser $closer): int
    {
        $queued = 0;
        foreach (DB::table('users')->whereNull('deleted_at')->orderBy('id')->pluck('id') as $userId) {
            if (! $closer->isStale((string) $userId)) {
                continue;
            }
            if ($this->option('sync')) {
                $closer->closeUser((string) $userId);
            } else {
                ClosePeriodsJob::dispatch((string) $userId);
            }
            $queued++;
        }
        $this->info("{$queued} user(s) closed or queued.");

        return self::SUCCESS;
    }
}
