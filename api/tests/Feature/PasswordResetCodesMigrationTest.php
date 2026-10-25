<?php

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

/*
 * A50: password_reset_codes constraints. The generic rollback check is MigrationRollbackTest.
 */

function resetCodeRow(string $userId, array $over = []): array
{
    return [
        'id' => (string) Str::uuid7(), 'user_id' => $userId, 'code_hash' => hash('sha256', (string) Str::uuid7()),
        'expires_at' => '2026-05-28 17:37:00+00', 'attempts' => 0, 'created_at' => '2026-05-28 17:22:00+00', ...$over,
    ];
}

it('keeps one open code per user and refuses a second, an attempt count outside 0 to 5 and a malformed hash', function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya');
    DB::table('password_reset_codes')->insert(resetCodeRow($maya['id'], ['consumed_at' => '2026-05-28 17:25:00+00']));
    DB::table('password_reset_codes')->insert(resetCodeRow($maya['id'], ['attempts' => 5]));
    expect(DB::table('password_reset_codes')->count())->toBe(2);

    foreach ([[], ['attempts' => 6, 'consumed_at' => '2026-05-28 17:25:00+00'], ['attempts' => -1, 'consumed_at' => '2026-05-28 17:25:00+00'], ['code_hash' => 'abc', 'consumed_at' => '2026-05-28 17:25:00+00']] as $bad) {
        expect(fn () => DB::transaction(fn () => DB::table('password_reset_codes')->insert(resetCodeRow($maya['id'], $bad))))
            ->toThrow(QueryException::class);
    }
});
