<?php

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

/*
 * A48: export_jobs constraints. The generic rollback check is MigrationRollbackTest.
 */

function exportRow(string $userId, array $over = []): array
{
    return [
        'id' => (string) Str::uuid7(), 'user_id' => $userId, 'format' => 'json', 'status' => 'queued',
        'created_at' => '2026-05-28 17:22:00+00', 'updated_at' => '2026-05-28 17:22:00+00', ...$over,
    ];
}

it('keeps a valid job and refuses an unknown format, an unknown status, an incomplete ready job and a failed job without a reason', function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya');
    DB::table('export_jobs')->insert(exportRow($maya['id']));
    DB::table('export_jobs')->insert(exportRow($maya['id'], [
        'status' => 'ready', 'object_key' => "exports/{$maya['id']}/x.zip", 'snapshot_seq' => 3, 'expires_at' => '2026-05-29 17:22:00+00',
    ]));
    expect(DB::table('export_jobs')->count())->toBe(2);

    foreach ([['format' => 'pdf'], ['status' => 'done'], ['status' => 'ready'], ['status' => 'failed']] as $bad) {
        expect(fn () => DB::transaction(fn () => DB::table('export_jobs')->insert(exportRow($maya['id'], $bad))))
            ->toThrow(QueryException::class);
    }
});
