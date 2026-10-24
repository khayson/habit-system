<?php

namespace App\Jobs;

use App\Application\Exports\ExportBuilder;
use App\Application\Exports\ExportStore;
use App\Domain\Clock;
use App\Support\UtcTime;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * A48: builds one export job's object. Queued (database driver). A failure marks the job failed
 * with an error_code and leaves no object behind; history is only ever read.
 */
final class RunExportJob implements ShouldQueue
{
    use Queueable;

    public int $tries = 1;

    public function __construct(public string $exportId) {}

    public function handle(ExportBuilder $builder, ExportStore $store, Clock $clock): void
    {
        $job = DB::table('export_jobs')->where('id', $this->exportId)->first();
        if ($job === null || $job->status !== 'queued') {
            return;
        }
        $now = fn () => UtcTime::format($clock->now());
        DB::table('export_jobs')->where('id', $job->id)->update(['status' => 'running', 'updated_at' => $now()]);

        $key = null;
        try {
            $built = $builder->build((string) $job->user_id, (string) $job->format);
            $key = $store->put((string) $job->user_id, $built['extension'], $built['bytes']);
            $hours = config()->integer('api.export_link_hours');
            DB::table('export_jobs')->where('id', $job->id)->update([
                'status' => 'ready', 'snapshot_seq' => $built['snapshot_seq'], 'object_key' => $key,
                'expires_at' => UtcTime::format($clock->now()->modify("+{$hours} hours")), 'updated_at' => $now(),
            ]);
        } catch (Throwable $e) {
            if ($key !== null) {
                $store->delete((string) $job->user_id, $key);
            }
            // Never the exception text: it could carry user data.
            Log::error('export failed', ['export_id' => $job->id, 'exception' => $e::class]);
            DB::table('export_jobs')->where('id', $job->id)->update([
                'status' => 'failed', 'error_code' => 'export_failed', 'object_key' => null, 'updated_at' => $now(),
            ]);
        }
    }
}
