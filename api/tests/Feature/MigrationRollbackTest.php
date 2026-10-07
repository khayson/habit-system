<?php

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

/*
 * Every migration has a rollback test: this one applies migrations one at a time, then rolls
 * each back and asserts the schema returns exactly to its state before that migration.
 * New migrations are covered automatically.
 */

/**
 * @return array<string, list<string>>
 */
function schemaSnapshot(): array
{
    $pluck = fn (string $sql): array => array_map(fn ($row) => (string) $row->v, DB::select($sql));

    return [
        'tables' => $pluck("select table_name as v from information_schema.tables where table_schema = 'public' and table_name <> 'migrations' order by 1"),
        'columns' => $pluck("select table_name || '.' || column_name || ':' || data_type || ':' || is_nullable as v from information_schema.columns where table_schema = 'public' and table_name <> 'migrations' order by 1"),
        'indexes' => $pluck("select indexname as v from pg_indexes where schemaname = 'public' and tablename <> 'migrations' order by 1"),
        'constraints' => $pluck("select c.conname as v from pg_constraint c join pg_namespace n on n.oid = c.connamespace join pg_class t on t.oid = c.conrelid where n.nspname = 'public' and t.relname <> 'migrations' order by 1"),
        'types' => $pluck("select t.typname as v from pg_type t join pg_namespace n on n.oid = t.typnamespace where n.nspname = 'public' and t.typtype in ('e', 'd') order by 1"),
        // Objects owned by an extension (e.g. btree_gist) belong to the extension, not a migration.
        'functions' => $pluck("select p.proname as v from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') order by 1"),
    ];
}

it('rolls back every migration to the exact prior schema', function () {
    Artisan::call('db:wipe', ['--force' => true]);
    Artisan::call('migrate:install');

    $files = array_keys(app('migrator')->getMigrationFiles(database_path('migrations')));
    expect($files)->not->toBeEmpty();

    $before = [];
    foreach ($files as $name) {
        $before[$name] = schemaSnapshot();
        Artisan::call('migrate', ['--path' => database_path("migrations/{$name}.php"), '--realpath' => true, '--force' => true]);
        expect(schemaSnapshot())->not->toBe($before[$name], "{$name} changed nothing");
    }

    foreach (array_reverse($files) as $name) {
        Artisan::call('migrate:rollback', ['--step' => 1, '--force' => true]);
        expect(schemaSnapshot())->toBe($before[$name], "rollback of {$name} did not restore the prior schema");
    }

    expect(DB::table('migrations')->count())->toBe(0);

    // Up again after a full down: leaves the test database migrated for later suites.
    expect(Artisan::call('migrate', ['--force' => true]))->toBe(0);
});
