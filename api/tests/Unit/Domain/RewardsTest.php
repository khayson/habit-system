<?php

use App\Domain\Freeze\FreezeCandidate;
use App\Domain\Freeze\FreezeEvaluator;
use App\Domain\Freeze\FreezePolicy;
use App\Domain\Freeze\FreezePolicyVersion;
use App\Domain\Freeze\FreezeUsage;
use App\Domain\Freeze\FreezeUsageState;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Reward\XpRules;
use Tests\Support\DomainFixtures as F;

/** contract-fixtures/domain/xp.json and freezes.json */
it('applies XP entitlement transitions', function (array $case) {
    $rules = new XpRules;
    $entitlement = null;
    $net = 0;

    foreach ($case['steps'] as $i => $completed) {
        $transition = $rules->transition($entitlement, $completed);
        $entitlement = $transition->entitlement;
        $net += $transition->delta;

        expect([$transition->delta, $entitlement?->revision, $transition->reason, $entitlement?->state->value])
            ->toBe(array_values($case['expect'][$i]), "step {$i}");
    }
    expect($net)->toBe($case['net']);
})->with(fn () => F::named(F::load('xp')['toggles']));

it('awards XP only when a value crosses the target', function (array $case) {
    $type = HabitTypeRegistry::withBuiltins()->get($case['type']);
    $target = $type->parseTarget($case['target']);
    $rules = new XpRules;
    $entitlement = null;
    $deltas = [];

    foreach ($case['values'] as $wire) {
        $transition = $rules->transition($entitlement, $type->isComplete($type->parseValue($wire), $target));
        $entitlement = $transition->entitlement;
        $deltas[] = $transition->delta;
    }

    expect($deltas)->toBe($case['deltas'])->and(array_sum($deltas))->toBe($case['net']);
})->with(fn () => F::named(F::load('xp')['value_sequences']));

it('computes levels', function (array $row) {
    $level = (new XpRules)->level($row['xp']);

    expect([$level->level, $level->progressIntoLevel, $level->nextLevelThreshold])
        ->toBe([$row['level'], $row['progress_into_level'], $row['next_level_threshold']]);
})->with(function () {
    $out = [];
    foreach (F::load('xp')['levels'] as $row) {
        $out["{$row['xp']} XP"] = [$row];
    }

    return $out;
});

it('reproduces the spec award: 1,240 -> 1,250, Level 13, 50/100', function () {
    $award = F::load('xp')['award'];
    $rules = new XpRules;
    $delta = $rules->transition(null, $award['completed'])->delta;

    $level = $rules->level($award['xp_before'] + $delta);

    expect([$level->xp, $level->level, $level->progressIntoLevel, $level->nextLevelThreshold])
        ->toBe(array_values($award['expect']));
});

/** @param list<array{enabled: bool, effective_at: string}> $rows */
function policyFrom(array $rows): FreezePolicy
{
    return new FreezePolicy(array_map(fn ($r) => new FreezePolicyVersion($r['enabled'], F::instant($r['effective_at'])), $rows));
}

it('closes failed periods against the wallet', function (array $case) {
    $candidates = array_map(fn ($c) => new FreezeCandidate(
        $c['habit_id'], $c['period_key'], F::instant($c['ends_at']), $c['streak_at_risk'], $c['definition_version'], $c['closed'],
    ), $case['candidates']);
    $used = array_map(fn ($u) => FreezeUsage::keyOf($u[0], $u[1]), $case['used']);

    $closure = (new FreezeEvaluator)->closePeriods($case['balance'], policyFrom($case['policy']), $candidates, $used);

    $rows = array_map(fn ($d) => [$d->candidate->habitId, $d->candidate->periodKey, $d->outcome->value], $closure->decisions);
    expect($rows)->toBe($case['expect']['decisions'])
        ->and($closure->balance)->toBe($case['expect']['balance'])
        ->and(count($closure->ledger))->toBe($case['balance'] - $case['expect']['balance'])
        ->and(array_sum(array_map(fn ($e) => $e->delta, $closure->ledger)))->toBe($case['expect']['balance'] - $case['balance']);
})->with(fn () => F::named(F::load('freezes')['closures']));

it('grants freezes', function (array $case) {
    $evaluator = new FreezeEvaluator;
    $entry = $case['kind'] === 'signup'
        ? $evaluator->signupGrant($case['balance'])
        : $evaluator->monthlyGrant($case['balance'], $case['month'], $case['already_granted']);

    if ($case['expect'] === null) {
        expect($entry)->toBeNull();

        return;
    }
    expect([$entry?->delta, $entry?->sourceKey, $entry?->reason, $case['balance'] + (int) $entry?->delta])
        ->toBe([$case['expect']['delta'], $case['expect']['source_key'], $case['expect']['reason'], $case['expect']['balance']]);
})->with(fn () => F::named(F::load('freezes')['grants']));

it('refunds a protected period once on late completion', function (array $case) {
    [$habitId, $periodKey, $state] = $case['usage'];
    $usage = new FreezeUsage($habitId, $periodKey, FreezeUsageState::from($state));

    $refund = (new FreezeEvaluator)->refundLateCompletion($case['balance'], $usage);

    if ($case['expect'] === null) {
        expect($refund)->toBeNull();

        return;
    }
    expect([$refund?->entry->delta, $refund?->entry->reason, $refund?->entry->sourceKey, $refund?->balance, $refund?->usage->state->value])
        ->toBe(array_values($case['expect']));
})->with(fn () => F::named(F::load('freezes')['refunds']));
