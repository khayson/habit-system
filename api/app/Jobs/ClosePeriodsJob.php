<?php

namespace App\Jobs;

use App\Application\Periods\PeriodCloser;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * A10: closes one user's periods. Unique per user, so the scheduler never queues two runs for the
 * same person. The closer runs in one transaction, so a job killed mid-run leaves nothing
 * behind and the next run completes it.
 */
final class ClosePeriodsJob implements ShouldBeUnique, ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public function __construct(public readonly string $userId) {}

    public function uniqueId(): string
    {
        return $this->userId;
    }

    public function handle(PeriodCloser $closer): void
    {
        $closer->closeUser($this->userId);
    }
}
