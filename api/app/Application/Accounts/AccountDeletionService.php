<?php

namespace App\Application\Accounts;

use App\Application\Journal\ChangeJournal;
use App\Domain\Clock;
use App\Jobs\PurgeAccountJob;
use App\Models\User;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use stdClass;

/**
 * A49: deletes an account at once (sessions end, the purge is queued) and issues the status
 * receipt. The password check is the caller's (the controller, under its throttle).
 */
final readonly class AccountDeletionService
{
    public const int RECEIPT_DAYS = 35;

    public function __construct(private ChangeJournal $journal, private Clock $clock) {}

    /**
     * @return array{deletion: stdClass, receipt_token: string}
     */
    public function delete(string $userId): array
    {
        return DB::transaction(function () use ($userId): array {
            // Under the user lock: a writer that waited for this commit then gets AccountDeleted.
            $this->journal->lockUser($userId);
            $now = $this->clock->now();
            $at = UtcTime::format($now);
            $token = Str::random(48);
            $id = (string) Str::uuid7();

            DB::table('users')->where('id', $userId)->update(['deleted_at' => $at, 'updated_at' => $at]);
            // Every session and so every device: a device is its token row.
            DB::table('personal_access_tokens')->where('tokenable_type', (new User)->getMorphClass())
                ->where('tokenable_id', $userId)->delete();
            DB::table('account_deletions')->insert([
                'id' => $id, 'user_id' => $userId, 'status' => 'queued',
                'requested_at' => $at, 'purge_after' => $at,
                'receipt_hash' => hash('sha256', $token),
                'receipt_expires_at' => UtcTime::format($now->addDays(self::RECEIPT_DAYS)),
                'created_at' => $at, 'updated_at' => $at,
            ]);
            PurgeAccountJob::dispatch($id)->afterCommit();

            return [
                'deletion' => DB::table('account_deletions')->where('id', $id)->first() ?? throw new LogicException('Deletion vanished.'),
                'receipt_token' => $token,
            ];
        });
    }
}
