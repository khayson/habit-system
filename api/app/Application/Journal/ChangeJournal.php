<?php

namespace App\Application\Journal;

use App\Domain\Clock;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use LogicException;

/**
 * The per-user change journal (spec 04, A1). Every committed change, including deletes, gets a
 * seq allocated from users.change_seq under the user-row lock, in the same transaction as the
 * domain write. Because every writer for a user serialises on that row, commit order equals seq
 * order and a `seq > cursor` pull can never skip a row.
 */
final readonly class ChangeJournal
{
    public function __construct(private Clock $clock) {}

    /**
     * Takes the user lock (SELECT … FOR UPDATE). Call first in every transaction that writes
     * domain state for the user.
     */
    public function lockUser(string $userId): void
    {
        $this->assertInTransaction();
        if (DB::selectOne('SELECT id FROM users WHERE id = ? FOR UPDATE', [$userId]) === null) {
            throw new LogicException('Cannot lock a missing user.');
        }
    }

    /**
     * @param  'upsert'|'delete'  $operation
     * @param  array<string, mixed>  $payload
     * @return int the allocated seq
     */
    public function append(string $userId, string $entityType, string $entityId, string $operation, int $version, array $payload): int
    {
        $this->assertInTransaction();
        // The UPDATE also holds the row lock until commit, so allocation is serialised per user.
        $row = DB::selectOne('UPDATE users SET change_seq = change_seq + 1 WHERE id = ? RETURNING change_seq', [$userId]);
        if ($row === null) {
            throw new LogicException('Cannot journal for a missing user.');
        }
        $seq = (int) $row->change_seq;

        DB::table('server_changes')->insert([
            'user_id' => $userId,
            'seq' => $seq,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'operation' => $operation,
            'version' => $version,
            'payload' => json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE),
            'created_at' => UtcTime::format($this->clock->now()),
        ]);

        return $seq;
    }

    private function assertInTransaction(): void
    {
        if (DB::transactionLevel() < 1) {
            throw new LogicException('Journal writes must happen inside the domain transaction (invariant 6).');
        }
    }
}
