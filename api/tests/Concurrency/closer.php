<?php

/*
 * Child process for the closer race test: runs PeriodCloser::closeUser for one user N times,
 * each in its own transaction under the user lock, as the scheduled job would.
 *
 *   php tests/Concurrency/closer.php <user-id> <runs> <frozen-now>
 *
 * Prints the number of changed entities per run as JSON.
 */

use App\Application\Periods\PeriodCloser;
use App\Domain\Clock;
use App\Infrastructure\FrozenClock;
use Illuminate\Contracts\Console\Kernel;

[$script, $userId, $runs, $now] = $argv;

require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
$app->instance(Clock::class, new FrozenClock($now));

$closer = $app->make(PeriodCloser::class);
$changed = [];
for ($i = 0; $i < (int) $runs; $i++) {
    $changed[] = $closer->closeUser($userId);
    usleep(2000);
}
fwrite(STDOUT, json_encode($changed, JSON_THROW_ON_ERROR));
