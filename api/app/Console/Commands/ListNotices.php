<?php

namespace App\Console\Commands;

use App\Application\Notices\NoticeBoard;
use Illuminate\Console\Command;

/** A57: every notice, newest start first, with who it is for and its window. */
final class ListNotices extends Command
{
    protected $signature = 'notices:list';

    protected $description = 'List the notices for Today\'s carousel (A57).';

    public function handle(NoticeBoard $board): int
    {
        $this->table(['Id', 'Title', 'For', 'Starts', 'Ends'], array_map(
            fn (array $n) => [$n['id'], $n['title'], $n['audience'], $n['starts_at'], $n['ends_at'] ?? '–'],
            $board->all(),
        ));

        return self::SUCCESS;
    }
}
