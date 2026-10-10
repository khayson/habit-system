<?php

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/*
 * A20: the profile and avatar columns arrive on a users table that already has rows. The
 * generic rollback check is MigrationRollbackTest. Not wrapped in RefreshDatabase: it migrates
 * step by step. The schema is rebuilt afterwards.
 */

afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

it('keeps existing users and gives them an empty profile and no photo', function () {
    Artisan::call('db:wipe', ['--force' => true]);
    $migration = '2026_10_11_100010_add_profile_and_avatar_to_users';
    foreach (array_keys(app('migrator')->getMigrationFiles(database_path('migrations'))) as $name) {
        if ($name === $migration) {
            break;
        }
        Artisan::call('migrate', ['--path' => database_path("migrations/{$name}.php"), '--realpath' => true, '--force' => true]);
    }

    $user = (string) Str::uuid7();
    $now = '2026-05-28 17:22:00+00';
    DB::table('users')->insert(['id' => $user, 'name' => 'Maya', 'email' => 'm@example.com', 'password' => 'x', 'timezone' => 'UTC', 'version' => 3, 'created_at' => $now, 'updated_at' => $now]);

    Artisan::call('migrate', ['--path' => database_path("migrations/{$migration}.php"), '--realpath' => true, '--force' => true]);

    $row = DB::table('users')->where('id', $user)->first();
    expect([$row->name, (int) $row->version, $row->city, $row->country_code, $row->avatar_key, (int) $row->avatar_version, $row->avatar_sha256])
        ->toBe(['Maya', 3, null, null, null, 0, null]);

    DB::table('users')->where('id', $user)->update(['city' => 'Accra', 'country_code' => 'GH']);
    expect(fn () => DB::table('users')->where('id', $user)->update(['country_code' => 'gh']))->toThrow(QueryException::class);
});
