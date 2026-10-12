<?php

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/*
 * Phase 5.1 (A18 migrations 6 and 7): the reward tables arrive on a database that already has a
 * user, a habit and logs; they survive, and the constraints refuse what A40 / A41 forbid. The
 * generic rollback check is MigrationRollbackTest. Not wrapped in RefreshDatabase: it migrates
 * step by step; the schema is rebuilt afterwards.
 */

afterEach(fn () => Artisan::call('migrate:fresh', ['--force' => true]));

/** Migrates every file before $stop, then returns the ids of a user, a habit and its log. */
function seedBefore(string $stop): array
{
    Artisan::call('db:wipe', ['--force' => true]);
    foreach (array_keys(app('migrator')->getMigrationFiles(database_path('migrations'))) as $name) {
        if ($name === $stop) {
            break;
        }
        Artisan::call('migrate', ['--path' => database_path("migrations/{$name}.php"), '--realpath' => true, '--force' => true]);
    }
    $now = '2026-05-28 17:22:00+00';
    $user = (string) Str::uuid7();
    $habit = (string) Str::uuid7();
    $log = (string) Str::uuid7();
    DB::table('users')->insert(['id' => $user, 'name' => 'Maya', 'email' => 'm@example.com', 'password' => 'x', 'timezone' => 'UTC', 'version' => 3, 'created_at' => $now, 'updated_at' => $now]);
    DB::table('habits')->insert(['id' => $habit, 'user_id' => $user, 'name' => 'Water', 'type' => 'quantity', 'unit' => 'L', 'category' => 'health', 'target_value' => 2, 'frequency_type' => 'daily', 'frequency_config' => '{}', 'start_local_date' => '2026-05-01', 'created_at' => $now, 'updated_at' => $now]);
    DB::table('habit_logs')->insert(['id' => $log, 'user_id' => $user, 'habit_id' => $habit, 'log_date' => '2026-05-27', 'value' => 2, 'occurred_at' => $now, 'resolved_timezone' => 'UTC', 'definition_version' => 1, 'created_at' => $now, 'updated_at' => $now]);

    return [$user, $habit, $log];
}

function migrateOne(string $name): void
{
    Artisan::call('migrate', ['--path' => database_path("migrations/{$name}.php"), '--realpath' => true, '--force' => true]);
}

it('adds the XP tables; earlier users, habits and logs survive with reward_version 0', function () {
    [$user, $habit, $log] = seedBefore('2026_10_12_100011_create_xp_entitlements_and_ledger');
    migrateOne('2026_10_12_100011_create_xp_entitlements_and_ledger');

    $row = DB::table('users')->where('id', $user)->first();
    expect([(int) $row->version, (int) $row->reward_version, (int) $row->xp])->toBe([3, 0, 0])
        ->and(DB::table('habits')->where('id', $habit)->value('name'))->toBe('Water')
        ->and(DB::table('habit_logs')->where('id', $log)->value('log_date'))->toBe('2026-05-27');

    $now = '2026-05-28 17:22:00+00';
    $entitlement = (string) Str::uuid7();
    DB::table('xp_entitlements')->insert(['id' => $entitlement, 'user_id' => $user, 'habit_id' => $habit, 'log_date' => '2026-05-27', 'state' => 'active', 'revision' => 1, 'created_at' => $now, 'updated_at' => $now]);
    // One entitlement per habit-day.
    expect(fn () => DB::table('xp_entitlements')->insert(['id' => (string) Str::uuid7(), 'user_id' => $user, 'habit_id' => $habit, 'log_date' => '2026-05-27', 'state' => 'active', 'revision' => 1, 'created_at' => $now, 'updated_at' => $now]))
        ->toThrow(QueryException::class);
    // Only +10 and -10 are ledger deltas.
    expect(fn () => DB::table('xp_ledger')->insert(['id' => (string) Str::uuid7(), 'user_id' => $user, 'entitlement_id' => $entitlement, 'entitlement_revision' => 1, 'delta' => 20, 'reason' => 'completion', 'created_at' => $now]))
        ->toThrow(QueryException::class);
});

it('adds the freeze tables; earlier rows survive with protected_in_streak 0', function () {
    [$user, $habit] = seedBefore('2026_10_12_100012_create_freeze_wallet');
    $now = '2026-05-28 17:22:00+00';
    DB::table('habit_streak_cache')->insert(['habit_id' => $habit, 'current' => 3, 'longest' => 4, 'unit' => 'days', 'version' => 2, 'updated_at' => $now]);
    migrateOne('2026_10_12_100012_create_freeze_wallet');

    $cache = DB::table('habit_streak_cache')->where('habit_id', $habit)->first();
    expect([(int) $cache->current, (int) $cache->version, (int) $cache->protected_in_streak])->toBe([3, 2, 0]);

    $row = fn (string $kind, int $delta, string $key) => ['id' => (string) Str::uuid7(), 'user_id' => $user, 'kind' => $kind, 'delta' => $delta, 'reason' => 'x', 'source_key' => $key, 'created_at' => $now];
    DB::table('freeze_ledger')->insert($row('grant', 2, 'signup'));
    // One row per source_key.
    expect(fn () => DB::table('freeze_ledger')->insert($row('grant', 0, 'signup')))->toThrow(QueryException::class);
    // A spend is exactly -1; a grant at most +2.
    expect(fn () => DB::table('freeze_ledger')->insert($row('spend', -2, 'spend:a')))->toThrow(QueryException::class);
    expect(fn () => DB::table('freeze_ledger')->insert($row('grant', 3, 'month:2026-05')))->toThrow(QueryException::class);
    // The cached balance stays within 0..2.
    expect(fn () => DB::table('users')->where('id', $user)->update(['freeze_balance' => 3]))->toThrow(QueryException::class);
});
