<?php

namespace App\Console\Commands;

use App\Application\Ops\OpsStatus;
use Illuminate\Console\Command;

/** A55: the read-only ops status on the command line (Render's shell, or locally). */
final class ShowOpsStatus extends Command
{
    protected $signature = 'ops:status {--json : print the same JSON as GET /internal/status}';

    protected $description = 'Show whether the system is healthy, in numbers only (A55).';

    public function handle(OpsStatus $status): int
    {
        $s = $status->collect();
        if ($this->option('json')) {
            $this->line((string) json_encode($s, JSON_UNESCAPED_SLASHES));

            return self::SUCCESS;
        }
        $this->table(['', ''], [
            ['Live accounts', $s['accounts']['live']],
            ['Deletions pending', $s['accounts']['deletions_pending']],
            ['Check-ins (last 24 hours)', $s['check_ins_last_24h']],
            ['Jobs waiting', $s['queue']['waiting']],
            ['Oldest waiting', $s['queue']['oldest_waiting_seconds'] === null ? '–' : $s['queue']['oldest_waiting_seconds'].' s'],
            ['Jobs failed', $s['queue']['failed']],
            ['Last tick', $s['last_tick_at'] ?? 'never'],
            ['Reset-email failures (7 days)', $s['mail_failures']['last_7_days']],
            ['Last reset-email failure', $s['mail_failures']['last_at'] ?? '–'],
            ['Database', sprintf('%s MB of %s MB (%s%%)', round($s['database']['size_bytes'] / 1048576, 1), round($s['database']['limit_bytes'] / 1048576), $s['database']['used_percent'])],
            ['Minimum app build', $s['min_app_version']],
        ]);

        return self::SUCCESS;
    }
}
