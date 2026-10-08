<?php

use Tests\Support\DomainFixtures as F;
use Tests\Support\ScheduleCases;

/*
 * contract-fixtures/domain/schedule.json: the PHP reference is what the file says, and the file
 * is what the generator writes. The Dart HabitSchedule asserts the same rows.
 */

it('keeps schedule.json in step with the PHP reference', function () {
    expect((string) file_get_contents(ScheduleCases::path()))->toBe(ScheduleCases::encode());
    // load('schedule') — consumed here; see FixtureCoverageTest.
    expect(F::load('schedule')['cases'])->toHaveCount(7);
});
