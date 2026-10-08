<?php

namespace App\Jobs;

use App\Application\Periods\PeriodCloser;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * A10: closes one user's periods. Unique per user, so the scheduler never queues two runs for the
 * same person. The closer runs in one transaction, so a job killed mid-run leaves nothing
 * behind and the next run completes it.
 */
final class ClosePeriodsJob implements ShouldBeUnique, ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    /** H3: a killed worker never blocks this user's closer for more than 10 minutes. */
    public int $uniqueFor = 600;

    public function __construct(public readonly string $userId) {}

    public function uniqueId(): string
    {
        return $this->userId;
    }

    public function handle(PeriodCloser $closer): void
    {
        $closer->closeUser($this->userId);
    }

    /** Logs the user id only: no payloads, no personal data (invariant 11). */
    public function failed(?Throwable $exception): void
    {
        Log::warning('ClosePeriodsJob failed', ['user_id' => $this->userId]);
    }
}
