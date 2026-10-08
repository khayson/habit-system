<?php

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/*
 * The period_evaluations.user_id migration backfills rows that exist before it runs.
 * Not wrapped in RefreshDatabase: it migrates step by step. The schema is rebuilt afterwards.
 */

afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

it('backfills user_id from the habit and then requires it', function () {
    Artisan::call('db:wipe', ['--force' => true]);
    $migration = '2026_10_08_100006_add_user_id_to_period_evaluations';
    foreach (array_keys(app('migrator')->getMigrationFiles(database_path('migrations'))) as $name) {
        if ($name === $migration) {
            break;
        }
        Artisan::call('migrate', ['--path' => database_path("migrations/{$name}.php"), '--realpath' => true, '--force' => true]);
    }

    $user = (string) Str::uuid7();
    $habit = (string) Str::uuid7();
    $now = '2026-05-28 17:22:00+00';
    DB::table('users')->insert(['id' => $user, 'name' => 'M', 'email' => 'm@example.com', 'password' => 'x', 'timezone' => 'UTC', 'created_at' => $now, 'updated_at' => $now]);
    DB::table('habits')->insert(['id' => $habit, 'user_id' => $user, 'name' => 'H', 'type' => 'binary', 'category' => 'health', 'target_value' => 1, 'frequency_type' => 'daily', 'frequency_config' => '{}', 'start_local_date' => '2026-05-01', 'created_at' => $now, 'updated_at' => $now]);
    DB::table('period_evaluations')->insert([
        'id' => (string) Str::uuid7(), 'habit_id' => $habit, 'period_key' => 'd:2026-05-27', 'definition_version' => 1,
        'start_date' => '2026-05-27', 'end_date' => '2026-05-27', 'timezone' => 'UTC',
        'starts_at' => '2026-05-27 00:00:00+00', 'ends_at' => '2026-05-28 00:00:00+00',
        'completed' => true, 'protected' => false, 'created_at' => $now, 'updated_at' => $now,
    ]);

    Artisan::call('migrate', ['--path' => database_path("migrations/{$migration}.php"), '--realpath' => true, '--force' => true]);

    expect(DB::table('period_evaluations')->value('user_id'))->toBe($user);
    expect(fn () => DB::table('period_evaluations')->update(['user_id' => null]))->toThrow(QueryException::class);
});
