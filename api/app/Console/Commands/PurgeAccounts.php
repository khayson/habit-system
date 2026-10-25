<?php

namespace App\Console\Commands;

use App\Application\Accounts\AccountPurger;
use App\Domain\Clock;
use App\Jobs\PurgeAccountJob;
use App\Support\UtcTime;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * A49: queues (or with --sync runs) the purge of every deletion past purge_after not yet
 * completed. A completed deletion whose receipt has expired has no reader left and is removed
 * (6.2 review L1).
 */
final class PurgeAccounts extends Command
{
    protected $signature = 'accounts:purge {--sync : Purge inline instead of queueing}';

    protected $description = 'Purge deleted accounts whose purge is due and not yet completed';

    public function handle(AccountPurger $purger, Clock $clock): int
    {
        $due = DB::table('account_deletions')->whereIn('status', ['queued', 'purging'])
            ->where('purge_after', '<=', UtcTime::format($clock->now()))->orderBy('requested_at')->pluck('id');
        foreach ($due as $id) {
            if ($this->option('sync')) {
                $purger->purge((string) $id);
            } else {
                PurgeAccountJob::dispatch((string) $id);
            }
        }
        $removed = DB::table('account_deletions')->where('status', 'completed')
            ->where('receipt_expires_at', '<=', UtcTime::format($clock->now()))->delete();
        $this->info(count($due)." deletion(s) purged or queued, {$removed} expired record(s) removed.");

        return self::SUCCESS;
    }
}
