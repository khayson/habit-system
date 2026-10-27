<?php

namespace App\Console\Commands;

use App\Application\Admin\EmailCampaigns;
use Illuminate\Console\Command;

/** A59: starts due announcement campaigns and sends one batch under the daily cap. */
final class SendDueEmails extends Command
{
    protected $signature = 'emails:send-due';

    protected $description = 'Send the next batch of announcement emails (A59).';

    public function handle(EmailCampaigns $campaigns): int
    {
        $this->line('Sent '.$campaigns->sendDue().'.');

        return self::SUCCESS;
    }
}
