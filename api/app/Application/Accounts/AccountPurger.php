<?php

namespace App\Application\Accounts;

use App\Application\Avatars\AvatarStore;
use App\Application\Exports\ExportStore;
use App\Domain\Clock;
use App\Models\User;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use LogicException;

/**
 * A49: removes a deleted account's data. Objects first, by owner prefix (idempotent); then every
 * owned row in one transaction under the user lock, in dependency order, ending with the users
 * row. The deletion becomes completed (user_id null) in that same transaction, so a failure leaves
 * nothing half-applied and a retry starts over. Running it again after completion does nothing.
 */
final readonly class AccountPurger
{
    /**
     * Owned tables in delete order: [table, how rows are owned]. 'user' is user_id, 'habit' is
     * habit_id among the user's habits, 'token' is the Sanctum tokenable. A test compares this
     * list with the schema, so a new owned table cannot be missed.
     *
     * @var list<array{0: string, 1: 'user'|'habit'|'token'}>
     */
    public const array ORDER = [
        ['xp_ledger', 'user'],
        ['xp_entitlements', 'user'],
        ['freeze_usage', 'user'],
        ['freeze_ledger', 'user'],
        ['period_evaluations', 'user'],
        ['reminders', 'user'],
        ['habit_logs', 'user'],
        ['habit_streak_cache', 'habit'],
        ['habit_active_ranges', 'habit'],
        ['habit_definition_versions', 'habit'],
        ['habits', 'user'],
        ['mutation_receipts', 'user'],
        ['server_changes', 'user'],
        ['user_freeze_policy_versions', 'user'],
        ['user_timezone_history', 'user'],
        ['export_jobs', 'user'],
        ['password_reset_codes', 'user'],
        ['password_reset_failures', 'user'],
        ['personal_access_tokens', 'token'],
    ];

    public function __construct(
        private ExportStore $exports,
        private AvatarStore $avatars,
        private Clock $clock,
    ) {}

    public function purge(string $deletionId): void
    {
        $deletion = DB::table('account_deletions')->where('id', $deletionId)->first();
        if ($deletion === null || $deletion->status === 'completed' || $deletion->user_id === null) {
            return;
        }
        $userId = (string) $deletion->user_id;
        $user = DB::table('users')->where('id', $userId)->first();
        if ($user === null || $user->deleted_at === null) {
            throw new LogicException('Only a deleted account is purged.');
        }
        DB::table('account_deletions')->where('id', $deletionId)->where('status', 'queued')
            ->update(['status' => 'purging', 'updated_at' => UtcTime::format($this->clock->now())]);

        $this->exports->deleteAllFor($userId);
        $this->avatars->deleteAllFor($userId);

        DB::transaction(function () use ($deletionId, $userId): void {
            $user = DB::selectOne('SELECT id, deleted_at FROM users WHERE id = ? FOR UPDATE', [$userId]);
            if ($user === null || $user->deleted_at === null) {
                throw new LogicException('Only a deleted account is purged.');
            }
            $habits = DB::table('habits')->where('user_id', $userId)->select('id');
            foreach (self::ORDER as [$table, $owner]) {
                $rows = DB::table($table);
                match ($owner) {
                    'user' => $rows->where('user_id', $userId),
                    'habit' => $rows->whereIn('habit_id', $habits),
                    'token' => $rows->where('tokenable_type', (new User)->getMorphClass())->where('tokenable_id', $userId),
                };
                $rows->delete();
            }
            $now = UtcTime::format($this->clock->now());
            DB::table('account_deletions')->where('id', $deletionId)
                ->update(['status' => 'completed', 'completed_at' => $now, 'user_id' => null, 'updated_at' => $now]);
            DB::table('users')->where('id', $userId)->delete();
        });
        Log::info('account purged', ['deletion_id' => $deletionId]);
    }
}
