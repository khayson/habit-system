<?php

namespace App\Jobs;

use App\Application\Accounts\AccountPurger;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/** A49: purges one deleted account. Retried; accounts:purge also picks up any left behind. */
final class PurgeAccountJob implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    /** @var list<int> */
    public array $backoff = [60, 300];

    public function __construct(public string $deletionId) {}

    public function handle(AccountPurger $purger): void
    {
        $purger->purge($this->deletionId);
    }
}
