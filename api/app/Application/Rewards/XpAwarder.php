<?php

namespace App\Application\Rewards;

use App\Domain\Clock;
use App\Domain\Reward\XpEntitlement;
use App\Domain\Reward\XpEntitlementState;
use App\Domain\Reward\XpRules;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * A40: XP for a habit-day whose completion a log write changed. Called by every log write path
 * (set_value, increment, delete) inside the mutation's transaction, under the user lock. One
 * entitlement per (habit, log_date), revised and never deleted; a ledger row only when the
 * transition moves XP. Amounts come from XpRules, never from the client.
 */
final readonly class XpAwarder
{
    public function __construct(
        private XpRules $rules,
        private RewardState $rewards,
        private Clock $clock,
    ) {}

    /**
     * @param  bool  $wasComplete  the habit-day before this write
     * @param  bool  $isComplete  the habit-day after it
     */
    public function award(string $userId, string $habitId, string $logDate, bool $wasComplete, bool $isComplete, ?string $mutationId): void
    {
        if ($wasComplete === $isComplete) {
            // Nothing about completion changed: an edit that stays complete (including a day
            // complete before Phase 5) or stays incomplete earns nothing.
            return;
        }
        $row = DB::table('xp_entitlements')->where('habit_id', $habitId)->where('log_date', $logDate)->lockForUpdate()->first();
        $current = $row === null ? null : new XpEntitlement(XpEntitlementState::from((string) $row->state), (int) $row->revision);
        $transition = $this->rules->transition($current, $isComplete);
        if (! $transition->changed() || $transition->entitlement === null) {
            return;
        }

        $now = UtcTime::format($this->clock->now());
        $entitlement = $transition->entitlement;
        if ($row === null) {
            $id = (string) Str::uuid7();
            DB::table('xp_entitlements')->insert([
                'id' => $id, 'user_id' => $userId, 'habit_id' => $habitId, 'log_date' => $logDate,
                'amount' => XpRules::XP_PER_COMPLETION, 'state' => $entitlement->state->value,
                'revision' => $entitlement->revision, 'created_at' => $now, 'updated_at' => $now,
            ]);
        } else {
            $id = (string) $row->id;
            DB::table('xp_entitlements')->where('id', $id)->update([
                'state' => $entitlement->state->value, 'revision' => $entitlement->revision, 'updated_at' => $now,
            ]);
        }
        DB::table('xp_ledger')->insert([
            'id' => (string) Str::uuid7(), 'user_id' => $userId, 'entitlement_id' => $id,
            'entitlement_revision' => $entitlement->revision, 'delta' => $transition->delta,
            'reason' => $transition->reason, 'mutation_id' => $mutationId, 'created_at' => $now,
        ]);
        $this->rewards->apply($userId, $transition->delta, 0);
    }
}
