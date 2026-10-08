<?php

/*
 * Child process for the closer lock test. Takes the user-row lock, inserts a log for a closed day
 * the way a concurrent mutation would, says "locked", holds the lock, then commits.
 *
 *   php tests/Concurrency/lock_holder.php <user-id> <habit-id> <log-date> <hold-ms>
 */

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

[$script, $userId, $habitId, $logDate, $holdMs] = $argv;

require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

DB::transaction(function () use ($userId, $habitId, $logDate, $holdMs) {
    DB::selectOne('SELECT id FROM users WHERE id = ? FOR UPDATE', [$userId]);
    $now = '2026-05-30 17:00:00+00';
    DB::table('habit_logs')->insert([
        'id' => (string) Str::uuid7(), 'user_id' => $userId, 'habit_id' => $habitId, 'log_date' => $logDate,
        'value' => 1, 'occurred_at' => $logDate.' 18:00:00+00', 'completed_at' => $logDate.' 18:00:00+00',
        'resolved_timezone' => 'America/Los_Angeles', 'definition_version' => 1, 'version' => 1,
        'created_at' => $now, 'updated_at' => $now,
    ]);
    fwrite(STDOUT, "locked\n");
    fflush(STDOUT);
    usleep((int) $holdMs * 1000);
});
fwrite(STDOUT, "committed\n");
