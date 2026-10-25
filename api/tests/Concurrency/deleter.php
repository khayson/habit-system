<?php

/*
 * Child process for the A49 race test. Deletes the account through the real service inside an
 * outer transaction, says "locked" while it still holds the user lock, holds it, then commits.
 * The purge job is left on the database queue so the parent can look before purging.
 *
 *   php tests/Concurrency/deleter.php <user-id> <hold-ms> <frozen-now>
 */

use App\Application\Accounts\AccountDeletionService;
use App\Domain\Clock;
use App\Infrastructure\FrozenClock;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;

[$script, $userId, $holdMs, $now] = $argv;

require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
$app->instance(Clock::class, new FrozenClock($now));
config(['queue.default' => 'database']);

DB::transaction(function () use ($app, $userId, $holdMs) {
    $app->make(AccountDeletionService::class)->delete($userId);
    fwrite(STDOUT, "locked\n");
    fflush(STDOUT);
    usleep((int) $holdMs * 1000);
});
fwrite(STDOUT, "committed\n");
