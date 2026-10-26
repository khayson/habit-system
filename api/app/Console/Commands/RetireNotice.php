<?php

namespace App\Console\Commands;

use App\Application\Notices\NoticeBoard;
use Illuminate\Console\Command;

/** A57: ends a notice now (one not started yet is removed). */
final class RetireNotice extends Command
{
    protected $signature = 'notices:retire {id}';

    protected $description = 'End a notice now (A57).';

    public function handle(NoticeBoard $board): int
    {
        $id = (string) $this->argument('id');
        if (! $board->retire($id)) {
            $this->error("No live notice {$id}.");

            return self::FAILURE;
        }
        $this->info("Retired {$id}.");

        return self::SUCCESS;
    }
}
