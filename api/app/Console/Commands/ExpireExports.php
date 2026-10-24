<?php

namespace App\Console\Commands;

use App\Application\Exports\ExportStore;
use App\Domain\Clock;
use App\Support\UtcTime;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/** A48: ready exports past their 24 hours become expired and lose their object. */
final class ExpireExports extends Command
{
    protected $signature = 'exports:expire';

    protected $description = 'Mark ready exports past expires_at as expired and delete their objects';

    public function handle(ExportStore $store, Clock $clock): int
    {
        $now = UtcTime::format($clock->now());
        $count = 0;
        $jobs = DB::table('export_jobs')->where('status', 'ready')->where('expires_at', '<=', $now)->get();
        foreach ($jobs as $job) {
            if ($job->object_key !== null) {
                $store->delete((string) $job->user_id, (string) $job->object_key);
            }
            $count += DB::table('export_jobs')->where('id', $job->id)->where('status', 'ready')
                ->update(['status' => 'expired', 'object_key' => null, 'updated_at' => $now]);
        }
        $this->info("{$count} export(s) expired.");

        return self::SUCCESS;
    }
}
