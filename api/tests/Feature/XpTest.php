<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A40 through the real /sync path: one entitlement per (habit, log_date), revised and never
 * deleted; a ledger row only when completion changes. Los Angeles; 17:22Z on 28 May is 10:22.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->water = (string) Str::uuid7();
    $this->sync($this->maya['token'], [
        M::habitCreate($this->water, 'quantity', '2000.000', ['unit' => 'mL', 'start_local_date' => '2026-05-01', 'date_mode' => 'backdate']),
    ])->assertOk();
});

/** One set_value on the habit-day, from the day's current log version. */
function putDay(object $test, string $token, string $habit, mixed $value, string $date = '2026-05-28', ?string $mutationId = null): array
{
    $log = DB::table('habit_logs')->where('habit_id', $habit)->where('log_date', $date)->first();

    return $test->sync($token, [M::setValue($habit, $value, $log === null ? 0 : (int) $log->version, "{$date}T17:00:00Z", $mutationId, $log?->id)])
        ->assertOk()->json('data.acks.0');
}

function incrementToday(object $test, string $token, string $habit, string $delta): array
{
    return $test->sync($token, [[
        'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit_log', 'entity_id' => (string) Str::uuid7(),
        'operation' => 'log.increment', 'base_version' => null, 'occurred_at' => '2026-05-28T17:00:00Z',
        'captured_timezone' => 'America/Los_Angeles', 'payload' => ['habit_id' => $habit, 'delta' => $delta],
    ]])->assertOk()->json('data.acks.0');
}

function xpOf(string $userId): int
{
    return (int) DB::table('users')->where('id', $userId)->value('xp');
}

/** @return list<int> */
function xpDeltas(string $userId): array
{
    return DB::table('xp_ledger')->where('user_id', $userId)->orderBy('created_at')->orderBy('id')->pluck('delta')->map(fn ($d) => (int) $d)->all();
}

it('nets +10, 0, -10, 0, +10 to 10 XP with three ledger rows and one entitlement at revision 3', function () {
    foreach (['2500.000', '3000.000', '1000.000', '500.000', '2000.000'] as $value) {
        expect(putDay($this, $this->maya['token'], $this->water, $value)['status'])->toBe('accepted');
    }

    $entitlement = DB::table('xp_entitlements')->where('habit_id', $this->water)->sole();
    expect(xpOf($this->maya['id']))->toBe(10)
        ->and(xpDeltas($this->maya['id']))->toBe([10, -10, 10])
        ->and(DB::table('xp_ledger')->orderBy('entitlement_revision')->pluck('reason')->all())->toBe(['completion', 'reversal', 'recompletion'])
        ->and((int) $entitlement->revision)->toBe(3)
        ->and($entitlement->state)->toBe('active')
        ->and($entitlement->log_date)->toBe('2026-05-28');
    assertLedgersMatchCaches($this->maya['id']);
});

it('awards once when an increment crosses the target, and nothing for the increments after', function () {
    incrementToday($this, $this->maya['token'], $this->water, '1500.000');
    expect(xpOf($this->maya['id']))->toBe(0);
    incrementToday($this, $this->maya['token'], $this->water, '600.000');
    incrementToday($this, $this->maya['token'], $this->water, '100.000');

    expect(xpOf($this->maya['id']))->toBe(10)->and(xpDeltas($this->maya['id']))->toBe([10]);
    assertLedgersMatchCaches($this->maya['id']);
});

it('awards nothing for a partial day and keeps no entitlement for it', function () {
    putDay($this, $this->maya['token'], $this->water, '1500.000');

    expect(xpOf($this->maya['id']))->toBe(0)
        ->and(DB::table('xp_entitlements')->count())->toBe(0)
        ->and((int) DB::table('users')->where('id', $this->maya['id'])->value('reward_version'))->toBe(1, 'only the signup grant');
    assertLedgersMatchCaches($this->maya['id']);
});

it('reverses a deleted completed day and writes nothing for a deleted incomplete one', function () {
    putDay($this, $this->maya['token'], $this->water, '2000.000');
    putDay($this, $this->maya['token'], $this->water, '500.000', '2026-05-27');
    foreach (['2026-05-28', '2026-05-27'] as $date) {
        $log = DB::table('habit_logs')->where('log_date', $date)->sole();
        expect($this->sync($this->maya['token'], [M::delete($log->id, (int) $log->version, $this->water)])->json('data.acks.0.status'))->toBe('accepted');
    }

    expect(xpOf($this->maya['id']))->toBe(0)
        ->and(xpDeltas($this->maya['id']))->toBe([10, -10])
        ->and(DB::table('xp_entitlements')->sole()->state)->toBe('reversed');
    assertLedgersMatchCaches($this->maya['id']);
});

it('gives nothing for editing a day completed before Phase 5, and never goes below zero for it', function () {
    putDay($this, $this->maya['token'], $this->water, '2500.000');
    // A day completed before the XP hook existed: the log, no entitlement and no XP.
    DB::table('xp_ledger')->delete();
    DB::table('xp_entitlements')->delete();
    DB::table('users')->where('id', $this->maya['id'])->update(['xp' => 0]);

    putDay($this, $this->maya['token'], $this->water, '3000.000');
    expect(xpDeltas($this->maya['id']))->toBe([]);
    putDay($this, $this->maya['token'], $this->water, '500.000');
    expect(xpOf($this->maya['id']))->toBe(0)->and(xpDeltas($this->maya['id']))->toBe([]);
    putDay($this, $this->maya['token'], $this->water, '2000.000');

    expect(xpOf($this->maya['id']))->toBe(10)->and(xpDeltas($this->maya['id']))->toBe([10]);
});

it('awards a backdated completion on its own date', function () {
    putDay($this, $this->maya['token'], $this->water, '2000.000', '2026-05-22');

    expect(xpOf($this->maya['id']))->toBe(10)
        ->and(DB::table('xp_entitlements')->sole()->log_date)->toBe('2026-05-22');
    assertLedgersMatchCaches($this->maya['id']);
});

it('awards the same XP for a completed day that was not due (A40, confirmed 2026-10-12)', function () {
    $mwf = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($mwf, overrides: [
        'frequency_type' => 'weekdays', 'frequency_config' => ['days' => [1, 3, 5]], 'start_local_date' => '2026-05-18', 'date_mode' => 'backdate',
    ])])->assertOk();

    putDay($this, $this->maya['token'], $mwf, 1, '2026-05-23'); // a Saturday

    expect(xpOf($this->maya['id']))->toBe(10)->and(xpDeltas($this->maya['id']))->toBe([10]);
    assertLedgersMatchCaches($this->maya['id']);
});

it('awards a replayed mutation once', function () {
    $id = (string) Str::uuid7();
    $mutation = M::setValue($this->water, '2000.000', 0, '2026-05-28T17:00:00Z', $id);
    $this->sync($this->maya['token'], [$mutation])->assertOk();
    $replay = $this->sync($this->maya['token'], [$mutation])->assertOk()->json('data.acks.0');

    expect($replay['status'])->toBe('accepted')
        ->and(xpOf($this->maya['id']))->toBe(10)
        ->and(xpDeltas($this->maya['id']))->toBe([10])
        ->and(DB::table('xp_ledger')->value('mutation_id'))->toBe($id);
    assertLedgersMatchCaches($this->maya['id']);
});
