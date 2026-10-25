<?php

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

/*
 * A49: account_deletions constraints. The generic rollback check is MigrationRollbackTest.
 */

function deletionRow(?string $userId, array $over = []): array
{
    return [
        'id' => (string) Str::uuid7(), 'user_id' => $userId, 'status' => 'queued',
        'requested_at' => '2026-05-28 17:22:00+00', 'purge_after' => '2026-05-28 17:22:00+00',
        'receipt_hash' => hash('sha256', (string) Str::uuid7()), 'receipt_expires_at' => '2026-07-02 17:22:00+00',
        'created_at' => '2026-05-28 17:22:00+00', 'updated_at' => '2026-05-28 17:22:00+00', ...$over,
    ];
}

it('keeps valid deletions and refuses an unknown status, completion without its time, a time without completion, a short hash and a reused hash', function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya');
    DB::table('account_deletions')->insert(deletionRow($maya['id']));
    DB::table('account_deletions')->insert(deletionRow(null, ['status' => 'completed', 'completed_at' => '2026-05-28 17:30:00+00']));
    expect(DB::table('account_deletions')->count())->toBe(2);

    $taken = (string) DB::table('account_deletions')->value('receipt_hash');
    foreach ([
        ['status' => 'done'],
        ['status' => 'completed'],
        ['completed_at' => '2026-05-28 17:30:00+00'],
        ['receipt_hash' => 'abc'],
        ['receipt_hash' => $taken],
    ] as $bad) {
        expect(fn () => DB::transaction(fn () => DB::table('account_deletions')->insert(deletionRow($maya['id'], $bad))))
            ->toThrow(QueryException::class);
    }
});

it('survives the purge of its user with user_id set to null', function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya');
    DB::table('account_deletions')->insert(deletionRow($maya['id']));
    DB::table('personal_access_tokens')->where('tokenable_id', $maya['id'])->delete();
    DB::table('user_timezone_history')->where('user_id', $maya['id'])->delete();
    DB::table('server_changes')->where('user_id', $maya['id'])->delete();
    DB::table('users')->where('id', $maya['id'])->delete();

    expect(DB::table('account_deletions')->value('user_id'))->toBeNull();
});
