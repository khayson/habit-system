<?php

/*
 * Generates contract-fixtures/domain/calendar_boundaries.json (H1): zone changes crossed
 * pairwise at several instants (DST edges included), with the A26 effective instant and, for
 * the dates within 3 days of it, start, end and zero_length. PHP is the reference; the Dart suite
 * asserts the same rows. Re-run after changing the rules:
 *
 *   php tests/Support/generate_calendar_boundaries.php
 *
 * CalendarBoundariesTest fails when the file and this generator disagree.
 */

use Tests\Support\CalendarBoundaryCases;

require __DIR__.'/../../vendor/autoload.php';

fwrite(STDOUT, 'cases: '.count(CalendarBoundaryCases::fixture()['generated'])."\n");
file_put_contents(CalendarBoundaryCases::path(), CalendarBoundaryCases::encode());
