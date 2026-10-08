<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// A10: close finished periods every 5 minutes (one unique job per stale user).
// H3: the overlap lock expires after 10 minutes, so a crashed run never blocks the next ones.
Schedule::command('habits:close-periods')->everyFiveMinutes()->withoutOverlapping(10);
