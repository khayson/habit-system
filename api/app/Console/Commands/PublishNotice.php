<?php

namespace App\Console\Commands;

use App\Application\Notices\NoticeBoard;
use Illuminate\Console\Command;
use InvalidArgumentException;

/** A57: publishes a notice for Today's carousel (plain text; invariant 12's copy rules apply). */
final class PublishNotice extends Command
{
    protected $signature = 'notices:publish
        {--title= : 1 to 60 characters}
        {--body= : 1 to 280 characters, plain text}
        {--starts= : ISO-8601 with a zone; now when left out}
        {--ends= : ISO-8601 with a zone; optional}';

    protected $description = 'Publish a notice to every account\'s Today carousel (A57).';

    public function handle(NoticeBoard $board): int
    {
        try {
            $id = $board->publish(
                (string) $this->option('title'),
                (string) $this->option('body'),
                $this->option('starts') === null ? null : (string) $this->option('starts'),
                $this->option('ends') === null ? null : (string) $this->option('ends'),
            );
        } catch (InvalidArgumentException $e) {
            $this->error($e->getMessage());

            return self::FAILURE;
        }
        $this->info("Published {$id}.");

        return self::SUCCESS;
    }
}
