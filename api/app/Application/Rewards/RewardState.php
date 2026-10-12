<?php

namespace App\Application\Rewards;

use App\Application\Journal\ChangeJournal;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use LogicException;

/**
 * A39: the one writer of the cached reward numbers. Every xp_ledger or freeze_ledger row that
 * changes users.xp or users.freeze_balance comes through here, in the caller's transaction under
 * the user lock (A1): the cache moves, reward_version rises by one and reward_state is journaled
 * (invariant 6). A zero-delta audit row changes nothing and is never passed here.
 */
final readonly class RewardState
{
    public function __construct(
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    public function apply(string $userId, int $xpDelta, int $freezeDelta): void
    {
        if ($xpDelta === 0 && $freezeDelta === 0) {
            return;
        }
        $row = DB::selectOne(
            'UPDATE users SET xp = xp + ?, freeze_balance = freeze_balance + ?, reward_version = reward_version + 1, updated_at = ?
             WHERE id = ? RETURNING *',
            [$xpDelta, $freezeDelta, UtcTime::format($this->clock->now()), $userId],
        ) ?? throw new LogicException('Cannot reward a missing user.');
        $this->journal->append($userId, 'reward_state', $userId, 'upsert', (int) $row->reward_version, $this->presenter->rewardState($row));
    }
}
