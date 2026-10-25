<?php

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A51: habits.deleted_at and its constraint. The generic rollback check is MigrationRollbackTest.
 */

it('lets a deleted habit keep only an empty name', function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya');
    $habit = (string) Str::uuid7();
    $this->sync($maya['token'], [M::habitCreate($habit)])->assertOk();

    expect(fn () => DB::transaction(fn () => DB::table('habits')->where('id', $habit)->update(['deleted_at' => '2026-05-28 17:30:00+00'])))
        ->toThrow(QueryException::class);
    DB::table('habits')->where('id', $habit)->update(['deleted_at' => '2026-05-28 17:30:00+00', 'name' => '']);
    expect(DB::table('habits')->where('id', $habit)->value('name'))->toBe('');
});
