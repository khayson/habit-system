<?php

use App\Domain\Freeze\FreezeCandidate;
use App\Domain\Freeze\FreezeEvaluator;
use App\Domain\Freeze\FreezeOutcome;
use App\Domain\Freeze\FreezePolicy;
use App\Domain\Freeze\FreezePolicyVersion;
use App\Domain\Freeze\FreezeUsage;
use App\Domain\Freeze\FreezeUsageState;
use App\Domain\Reward\XpEntitlementState;
use App\Domain\Reward\XpRules;
use Tests\Support\DomainFixtures as F;

/*
 * Property tests with fixed seeds: deterministic in CI, broad in coverage. A failure message
 * names the seed and step so it can be replayed.
 */

const PROPERTY_SEEDS = [1, 7, 42, 2026, 31337];

/** @return list<FreezeCandidate> */
function randomCandidates(int $n): array
{
    $habits = ['01970000-0000-7000-8000-00000000000a', '01970000-0000-7000-8000-00000000000b', '01970000-0000-7000-8000-00000000000c'];
    $out = [];
    for ($i = 0; $i < $n; $i++) {
        $day = mt_rand(1, 28);
        $out[] = new FreezeCandidate(
            $habits[mt_rand(0, 2)],
            sprintf('d:2026-05-%02d', $day),
            F::instant(sprintf('2026-05-%02dT07:00:00Z', $day))->modify('+1 day'),
            mt_rand(0, 20),
            1,
            mt_rand(0, 9) > 0,
        );
    }

    return $out;
}

function randomPolicy(): FreezePolicy
{
    return new FreezePolicy([
        new FreezePolicyVersion((bool) mt_rand(0, 1), F::instant('2026-01-01T00:00:00Z')),
        new FreezePolicyVersion((bool) mt_rand(0, 1), F::instant(sprintf('2026-05-%02dT12:00:00Z', mt_rand(1, 28)))),
    ]);
}

it('keeps the freeze balance within [0, 2] under any sequence of grants, spends and refunds', function (int $seed) {
    mt_srand($seed);
    $evaluator = new FreezeEvaluator;
    $balance = 0;
    $usages = [];
    $months = [];

    for ($step = 0; $step < 400; $step++) {
        switch (mt_rand(0, 3)) {
            case 0:
                $month = sprintf('2026-%02d', mt_rand(1, 12));
                $entry = $evaluator->monthlyGrant($balance, $month, isset($months[$month]));
                $months[$month] = true;
                $balance += $entry === null ? 0 : $entry->delta;
                break;
            case 1:
            case 2:
                $closure = $evaluator->closePeriods($balance, randomPolicy(), randomCandidates(mt_rand(1, 5)), array_keys($usages));
                foreach ($closure->usages as $usage) {
                    $usages[$usage->key()] = $usage;
                }
                expect(count($closure->ledger))->toBe($balance - $closure->balance);
                $balance = $closure->balance;
                break;
            default:
                $active = array_filter($usages, fn (FreezeUsage $u) => $u->state === FreezeUsageState::Active);
                if ($active !== []) {
                    $usage = $active[array_rand($active)];
                    $refund = $evaluator->refundLateCompletion($balance, $usage);
                    $usages[$usage->key()] = $refund?->usage ?? $usage;
                    $balance = $refund?->balance ?? $balance;
                }
        }
        expect($balance)->toBeGreaterThanOrEqual(0, "seed {$seed} step {$step}")
            ->toBeLessThanOrEqual(FreezeEvaluator::CAP, "seed {$seed} step {$step}");
    }
})->with(PROPERTY_SEEDS);

it('is idempotent: re-running a closure with its own results spends nothing more', function (int $seed) {
    mt_srand($seed);
    $evaluator = new FreezeEvaluator;

    for ($round = 0; $round < 50; $round++) {
        $candidates = randomCandidates(mt_rand(1, 8));
        $policy = randomPolicy();
        $first = $evaluator->closePeriods(mt_rand(0, 2), $policy, $candidates, []);
        $used = array_map(fn (FreezeUsage $u) => $u->key(), $first->usages);

        $second = $evaluator->closePeriods($first->balance, $policy, $candidates, $used);

        expect($second->ledger)->toBe([], "seed {$seed} round {$round}")
            ->and($second->balance)->toBe($first->balance);
        foreach ($second->decisions as $decision) {
            expect($decision->outcome)->not->toBe(FreezeOutcome::Spent);
        }
        // At most one spend per (habit, period) even when a batch repeats a period.
        expect(count($used))->toBe(count(array_unique($used)));
    }
})->with(PROPERTY_SEEDS);

it('nets zero XP for any toggle sequence that ends incomplete, and +10 when it ends complete', function (int $seed) {
    mt_srand($seed);
    $rules = new XpRules;

    for ($round = 0; $round < 200; $round++) {
        $entitlement = null;
        $net = 0;
        $completed = false;
        $revisions = [];
        for ($i = 0, $n = mt_rand(1, 12); $i < $n; $i++) {
            $completed = (bool) mt_rand(0, 1);
            $transition = $rules->transition($entitlement, $completed);
            $entitlement = $transition->entitlement;
            $net += $transition->delta;
            expect($net)->toBeGreaterThanOrEqual(0)->toBeLessThanOrEqual(XpRules::XP_PER_COMPLETION);
            if ($transition->changed()) {
                $revisions[] = $entitlement?->revision;
            }
        }

        expect($net)->toBe($completed ? XpRules::XP_PER_COMPLETION : 0, "seed {$seed} round {$round}")
            ->and($entitlement === null || ($entitlement->state === XpEntitlementState::Active) === $completed)->toBeTrue()
            // Ledger rows carry unique, increasing entitlement revisions.
            ->and($revisions)->toBe(array_values(array_unique($revisions)));
    }
})->with(PROPERTY_SEEDS);
