<?php

/*
 * Generates contract-fixtures/domain/schedule.json from the PHP reference (HabitSchedule +
 * PeriodEngine). Re-run after changing schedule rules:
 *
 *   php tests/Support/generate_schedule.php
 *
 * ScheduleFixtureTest fails when the file and this generator disagree.
 */

use Tests\Support\ScheduleCases;

require __DIR__.'/../../vendor/autoload.php';

file_put_contents(ScheduleCases::path(), ScheduleCases::encode());
fwrite(STDOUT, 'cases: '.count(ScheduleCases::fixture()['cases'])."\n");
