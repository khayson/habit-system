<?php

namespace App\Domain\Freeze;

use InvalidArgumentException;

/**
 * Freeze wallet rules (amendments 0.2, spec 08, A8, A11). Pure: callers hold the user lock (A1)
 * and persist the returned ledger rows and usages in one transaction.
 *
 * - Balance is always within [0, CAP].
 * - A grant tops up to the cap; opt-in gates spending only (A11).
 * - Spending: one per (habit, period_key), for closed failed periods only, while the policy in
 *   force at the period's end is enabled. Order: ends_at ASC, streak_at_risk DESC, habit_id ASC.
 * - A late real completion refunds min(1, CAP - balance) once; a zero refund is still written as
 *   a cap_reached audit row. A refunded usage never reactivates.
 */
final class FreezeEvaluator
{
    public const int CAP = 2;

    /** Account creation grant (A11). */
    public function signupGrant(int $balance): FreezeLedgerEntry
    {
        $this->assertBalance($balance);

        return new FreezeLedgerEntry(FreezeLedgerKind::Grant, self::CAP - $balance, 'signup', 'signup');
    }

    /**
     * Start-of-local-month top-up. Returns null when the month was already granted (retry).
     * At the cap it still returns a zero-delta row so the month is marked done.
     *
     * @param  string  $yearMonth  YYYY-MM in the user's calendar
     */
    public function monthlyGrant(int $balance, string $yearMonth, bool $alreadyGranted): ?FreezeLedgerEntry
    {
        $this->assertBalance($balance);
        if (preg_match('/^\d{4}-(0[1-9]|1[0-2])$/', $yearMonth) !== 1) {
            throw new InvalidArgumentException("Invalid month: {$yearMonth}");
        }
        if ($alreadyGranted) {
            return null;
        }
        $delta = self::CAP - $balance;

        return new FreezeLedgerEntry(FreezeLedgerKind::Grant, $delta, $delta > 0 ? 'monthly' : 'cap_reached', "month:{$yearMonth}");
    }

    /**
     * @param  list<FreezeCandidate>  $candidates
     * @param  list<string>  $usedKeys  FreezeUsage::key() of existing usages (active or refunded)
     */
    public function closePeriods(int $balance, FreezePolicy $policy, array $candidates, array $usedKeys): FreezeClosure
    {
        $this->assertBalance($balance);
        usort($candidates, fn (FreezeCandidate $a, FreezeCandidate $b) => $a->endsAt <=> $b->endsAt
            ?: $b->streakAtRisk <=> $a->streakAtRisk
            ?: strcmp($a->habitId, $b->habitId));

        $used = array_flip($usedKeys);
        $decisions = [];
        $ledger = [];
        $usages = [];

        foreach ($candidates as $candidate) {
            $outcome = match (true) {
                ! $candidate->closed => FreezeOutcome::PeriodOpen,
                isset($used[$candidate->usageKey()]) => FreezeOutcome::AlreadyUsed,
                ! $policy->enabledAt($candidate->endsAt) => FreezeOutcome::PolicyDisabled,
                $balance < 1 => FreezeOutcome::NoBalance,
                default => FreezeOutcome::Spent,
            };

            if ($outcome === FreezeOutcome::Spent) {
                $balance--;
                $used[$candidate->usageKey()] = true;
                $ledger[] = new FreezeLedgerEntry(FreezeLedgerKind::Spend, -1, 'missed_period', "spend:{$candidate->habitId}:{$candidate->periodKey}");
                $usages[] = new FreezeUsage($candidate->habitId, $candidate->periodKey, FreezeUsageState::Active, $candidate->definitionVersion);
            }
            $decisions[] = new FreezeDecision($candidate, $outcome);
        }

        return new FreezeClosure($decisions, $ledger, $usages, $balance);
    }

    /** A real completion arrived for a protected period. Null if the usage was already refunded. */
    public function refundLateCompletion(int $balance, FreezeUsage $usage): ?FreezeRefund
    {
        $this->assertBalance($balance);
        if ($usage->state === FreezeUsageState::Refunded) {
            return null;
        }
        $delta = min(1, self::CAP - $balance);
        $entry = new FreezeLedgerEntry(
            FreezeLedgerKind::Refund,
            $delta,
            $delta > 0 ? 'late_completion' : 'cap_reached',
            "refund:{$usage->habitId}:{$usage->periodKey}",
        );

        return new FreezeRefund($entry, $usage->refunded(), $balance + $delta);
    }

    private function assertBalance(int $balance): void
    {
        if ($balance < 0 || $balance > self::CAP) {
            throw new InvalidArgumentException('Freeze balance must be within 0..'.self::CAP);
        }
    }
}
