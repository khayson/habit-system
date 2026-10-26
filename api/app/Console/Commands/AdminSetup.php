<?php

namespace App\Console\Commands;

use App\Application\Admin\Totp;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

/**
 * A58: run once on Khay Studios' own computer. Asks for the admin password (hidden), then
 * prints the three values to paste into Render and the link to scan with an authenticator app.
 * Nothing is written anywhere; the output stays in that terminal.
 */
final class AdminSetup extends Command
{
    protected $signature = 'admin:setup {email : the admin sign-in email}';

    protected $description = 'Print the admin page settings for Render: the password hash and a new authenticator secret (A58).';

    public function handle(): int
    {
        $email = mb_strtolower(trim((string) $this->argument('email')));
        $password = (string) $this->secret('Admin password (16 or more characters)');
        if (mb_strlen($password) < 16) {
            $this->error('Use 16 or more characters.');

            return self::FAILURE;
        }
        if ($password !== (string) $this->secret('The same password again')) {
            $this->error('The two passwords differ.');

            return self::FAILURE;
        }
        $secret = Totp::newSecret();
        $this->line('Add these three under Render, Environment, then Save and deploy:');
        $this->line('');
        $this->line('ADMIN_EMAIL='.$email);
        $this->line('ADMIN_PASSWORD_HASH='.Hash::make($password));
        $this->line('ADMIN_TOTP_SECRET='.$secret);
        $this->line('');
        $this->line('In your authenticator app, add an account with this key (or open the link on the phone):');
        $this->line(Totp::uri($secret, $email));
        $this->line('');
        $this->warn('Keep these out of the repository, chats and screenshots. Close this window when done.');

        return self::SUCCESS;
    }
}
