<?php

namespace App\Application\Rewards;

use App\Domain\Calendar\LocalDate;
use App\Domain\Clock;
use App\Domain\Freeze\FreezeCandidate;
use App\Domain\Freeze\FreezeEvaluator;
use App\Domain\Freeze\FreezeLedgerEntry;
use App\Domain\Freeze\FreezePolicy;
use App\Domain\Freeze\FreezePolicyVersion;
use App\Domain\Freeze\FreezeUsage;
use App\Domain\Freeze\FreezeUsageState;
use App\Support\UtcTime;
use App\Support\WireTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * A41: the freeze wallet around the pure FreezeEvaluator. Every method runs in the caller's
 * transaction under the user lock (A1) and writes the ledger rows, the usages and the cached
 * balance together; a row that moves the balance goes through RewardState, so reward_state is
 * journaled with it (A39). A zero-delta row is an audit and moves nothing.
 */
final readonly class FreezeWallet
{
    public function __construct(
        private FreezeEvaluator $evaluator,
        private RewardState $rewards,
        private Clock $clock,
    ) {}

    /** Registration (A11): top the new wallet up to the cap. */
    public function signupGrant(string $userId): void
    {
        $this->write($userId, $this->evaluator->signupGrant($this->balance($userId)));
    }

    /**
     * The local month's grant, once: a retry or a concurrent job finds the month's source_key
     * and credits nothing more.
     *
     * @param  string  $yearMonth  YYYY-MM in the user's calendar
     */
    public function monthlyGrant(string $userId, string $yearMonth): void
    {
        $granted = DB::table('freeze_ledger')->where('user_id', $userId)->where('source_key', "month:{$yearMonth}")->exists();
        $entry = $this->evaluator->monthlyGrant($this->balance($userId), $yearMonth, $granted);
        if ($entry !== null) {
            $this->write($userId, $entry);
        }
    }

    /**
     * One decision pass across all of the user's habits (A8 order). Returns the usage keys that
     * became protected.
     *
     * @param  list<FreezeCandidate>  $candidates
     * @return list<string>
     */
    public function spend(string $userId, array $candidates): array
    {
        if ($candidates === []) {
            return [];
        }
        $used = array_values(DB::table('freeze_usage')->where('user_id', $userId)->get(['habit_id', 'period_key'])
            ->map(fn ($u) => FreezeUsage::keyOf((string) $u->habit_id, (string) $u->period_key))->all());
        $closure = $this->evaluator->closePeriods($this->balance($userId), $this->policy($userId), $candidates, $used);

        $now = UtcTime::format($this->clock->now());
        $keys = [];
        foreach ($closure->usages as $i => $usage) {
            $ledgerId = $this->insert($userId, $closure->ledger[$i]);
            DB::table('freeze_usage')->insert([
                'id' => (string) Str::uuid7(), 'user_id' => $userId, 'habit_id' => $usage->habitId,
                'period_key' => $usage->periodKey, 'definition_version' => $usage->definitionVersion ?? 1,
                'used_on' => self::lastDay($usage->periodKey),
                'state' => FreezeUsageState::Active->value, 'spend_ledger_id' => $ledgerId,
                'created_at' => $now, 'updated_at' => $now,
            ]);
            $keys[] = $usage->key();
        }
        $this->rewards->apply($userId, 0, -count($closure->usages));

        return $keys;
    }

    /**
     * A late or edited log made a protected period complete: refund once (min(1, cap - balance),
     * a zero-delta cap_reached audit at the cap). A refunded usage never reactivates.
     */
    public function refund(string $userId, string $habitId, string $periodKey): void
    {
        $row = DB::table('freeze_usage')->where('habit_id', $habitId)->where('period_key', $periodKey)->lockForUpdate()->first();
        if ($row === null) {
            return;
        }
        $usage = new FreezeUsage($habitId, $periodKey, FreezeUsageState::from((string) $row->state), (int) $row->definition_version);
        $refund = $this->evaluator->refundLateCompletion($this->balance($userId), $usage);
        if ($refund === null) {
            return;
        }
        $ledgerId = $this->insert($userId, $refund->entry);
        $now = UtcTime::format($this->clock->now());
        DB::table('freeze_usage')->where('id', $row->id)->update([
            'state' => FreezeUsageState::Refunded->value, 'refund_ledger_id' => $ledgerId,
            'reconciled_at' => $now, 'updated_at' => $now,
        ]);
        $this->rewards->apply($userId, 0, $refund->entry->delta);
    }

    /** @return list<string> period keys of the habit's active (not refunded) usages */
    public function activeKeys(string $habitId): array
    {
        return array_values(DB::table('freeze_usage')->where('habit_id', $habitId)->where('state', FreezeUsageState::Active->value)
            ->pluck('period_key')->map(fn ($k) => (string) $k)->all());
    }

    /** The protected period's last local day: d:YYYY-MM-DD itself, or the Sunday of w:<Monday>. */
    private static function lastDay(string $periodKey): string
    {
        $date = LocalDate::fromString(substr($periodKey, 2));

        return (str_starts_with($periodKey, 'w:') ? $date->addDays(6) : $date)->toString();
    }

    private function policy(string $userId): FreezePolicy
    {
        return new FreezePolicy(array_values(DB::table('user_freeze_policy_versions')->where('user_id', $userId)->orderBy('effective_at')->orderBy('id')->get()
            ->map(fn ($v) => new FreezePolicyVersion((bool) $v->enabled, WireTime::parse((string) $v->effective_at)))->all()));
    }

    private function balance(string $userId): int
    {
        return (int) DB::table('users')->where('id', $userId)->value('freeze_balance');
    }

    private function write(string $userId, FreezeLedgerEntry $entry): void
    {
        $this->insert($userId, $entry);
        $this->rewards->apply($userId, 0, $entry->delta);
    }

    private function insert(string $userId, FreezeLedgerEntry $entry): string
    {
        $id = (string) Str::uuid7();
        DB::table('freeze_ledger')->insert([
            'id' => $id, 'user_id' => $userId, 'kind' => $entry->kind->value, 'delta' => $entry->delta,
            'reason' => $entry->reason, 'source_key' => $entry->sourceKey,
            'created_at' => UtcTime::format($this->clock->now()),
        ]);

        return $id;
    }
}
