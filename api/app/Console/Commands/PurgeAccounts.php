<?php

namespace App\Console\Commands;

use App\Application\Accounts\AccountPurger;
use App\Domain\Clock;
use App\Jobs\PurgeAccountJob;
use App\Support\UtcTime;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/** A49: queues (or with --sync runs) the purge of every deletion past purge_after not yet completed. */
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
        $this->info(count($due).' deletion(s) purged or queued.');

        return self::SUCCESS;
    }
}
