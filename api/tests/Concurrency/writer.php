<?php

/*
 * Child process for the A1 concurrency test. Boots the app against the same database as the
 * test and applies a list of mutations through the real MutationApplier, one transaction each.
 *
 *   php tests/Concurrency/writer.php <user-id> <device-id> <mutations.json> <frozen-now>
 *
 * Prints the acks as JSON on stdout.
 */

use App\Application\Mutations\MutationApplier;
use App\Domain\Clock;
use App\Infrastructure\FrozenClock;
use Illuminate\Contracts\Console\Kernel;

[$script, $userId, $deviceId, $file, $now] = $argv;

require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();
$app->instance(Clock::class, new FrozenClock($now));

/** @var list<array<string, mixed>> $mutations */
$mutations = json_decode((string) file_get_contents($file), true, flags: JSON_THROW_ON_ERROR);
$applier = $app->make(MutationApplier::class);

$acks = [];
foreach ($mutations as $mutation) {
    $acks[] = $applier->apply($userId, $deviceId, $mutation)->toArray();
}

fwrite(STDOUT, json_encode($acks, JSON_THROW_ON_ERROR));
