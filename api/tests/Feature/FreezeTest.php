<?php

use App\Application\Periods\PeriodCloser;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A41 / A42 through the real paths: registration, /sync and the period closer. Los Angeles;
 * the account opens at 09:00 local on Wednesday 20 May 2026.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-20T16:00:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->closeAt = function (string $instant): void {
        $this->freezeClock($instant);
        app(PeriodCloser::class)->closeUser($this->maya['id']);
    };
});

function setAutoFreeze(object $test, array $user, bool $enabled): array
{
    $version = (int) DB::table('users')->where('id', $user['id'])->value('version');

    return $test->sync($user['token'], [M::setAutoFreeze($user['id'], $enabled, $version)])->assertOk()->json('data.acks.0');
}

function dailyHabit(object $test, array $user, string $start = '2026-05-20', ?string $id = null): string
{
    $id ??= (string) Str::uuid7();
    $test->sync($user['token'], [M::habitCreate($id, overrides: ['start_local_date' => $start, 'date_mode' => 'backdate'])])->assertOk();

    return $id;
}

function balanceOf(string $userId): int
{
    return (int) DB::table('users')->where('id', $userId)->value('freeze_balance');
}

/** @return list<string> "kind:reason:delta", oldest first */
function freezeRows(string $userId): array
{
    return DB::table('freeze_ledger')->where('user_id', $userId)->orderBy('created_at')->orderBy('id')->get()
        ->map(fn ($r) => "{$r->kind}:{$r->reason}:{$r->delta}")->all();
}

/** @return list<string> "habit:period_key:state" */
function usages(string $userId): array
{
    return DB::table('freeze_usage')->where('user_id', $userId)->orderBy('period_key')->orderBy('habit_id')->get()
        ->map(fn ($u) => "{$u->habit_id}:{$u->period_key}:{$u->state}")->all();
}

it('grants two at signup and journals reward_state with them', function () {
    $journal = DB::table('server_changes')->where('user_id', $this->maya['id'])->where('entity_type', 'reward_state')->sole();

    expect(freezeRows($this->maya['id']))->toBe(['grant:signup:2'])
        ->and(balanceOf($this->maya['id']))->toBe(2)
        ->and((int) $journal->version)->toBe(1)
        ->and(json_decode($journal->payload, true)['freeze_balance'])->toBe(2);
    assertLedgersMatchCaches($this->maya['id']);
});

it('tops up once a month, writes cap_reached at the cap, and a retry credits nothing more', function () {
    setAutoFreeze($this, $this->maya, true);
    dailyHabit($this, $this->maya);
    ($this->closeAt)('2026-05-21T17:00:00Z'); // 20 May missed: one spent
    ($this->closeAt)('2026-05-21T17:00:00Z');
    setAutoFreeze($this, $this->maya, false);
    ($this->closeAt)('2026-06-01T17:00:00Z');
    ($this->closeAt)('2026-06-01T17:05:00Z');

    expect(freezeRows($this->maya['id']))->toBe([
        'grant:signup:2',
        'grant:cap_reached:0',     // month:2026-05 at the cap
        'spend:missed_period:-1',
        'grant:monthly:1',         // month:2026-06
    ])->and(DB::table('freeze_ledger')->where('kind', 'grant')->pluck('source_key')->all())->toBe(['signup', 'month:2026-05', 'month:2026-06'])
        ->and(balanceOf($this->maya['id']))->toBe(2);
    assertLedgersMatchCaches($this->maya['id']);
});

it('spends the one token on the longer streak when two habits fail the same day (A8 order)', function () {
    // B's id sorts first, so only the streak at risk can put A ahead.
    $b = (string) Str::uuid7();
    $a = (string) Str::uuid7();
    setAutoFreeze($this, $this->maya, true);
    dailyHabit($this, $this->maya, '2026-05-20', $a);
    dailyHabit($this, $this->maya, '2026-05-21', $b);
    ($this->closeAt)('2026-05-21T17:00:00Z'); // A misses 20 May: balance 1
    ($this->closeAt)('2026-05-22T17:00:00Z'); // both miss 21 May

    expect(usages($this->maya['id']))->toBe(["{$a}:d:2026-05-20:active", "{$a}:d:2026-05-21:active"])
        ->and(balanceOf($this->maya['id']))->toBe(0)
        ->and((bool) DB::table('period_evaluations')->where('habit_id', $b)->where('period_key', 'd:2026-05-21')->value('protected'))->toBeFalse()
        ->and((int) DB::table('habit_streak_cache')->where('habit_id', $a)->value('protected_in_streak'))->toBe(2)
        ->and((int) DB::table('habit_streak_cache')->where('habit_id', $a)->value('current'))->toBe(2);
    assertLedgersMatchCaches($this->maya['id']);
});

it('costs one token for a failed week', function () {
    setAutoFreeze($this, $this->maya, true);
    $weekly = (string) Str::uuid7();
    $this->sync($this->maya['token'], [
        M::habitCreate($weekly, overrides: ['frequency_type' => 'weekly_count', 'frequency_config' => ['count' => 3], 'start_local_date' => '2026-05-18', 'date_mode' => 'backdate']),
        M::setValue($weekly, 1, 0, '2026-05-20T16:00:00Z'),
    ])->assertOk();
    ($this->closeAt)('2026-05-22T17:00:00Z');
    expect(usages($this->maya['id']))->toBe([], 'the week is still open');

    ($this->closeAt)('2026-05-25T17:00:00Z');

    expect(usages($this->maya['id']))->toBe(["{$weekly}:w:2026-05-18:active"])
        ->and(DB::table('freeze_usage')->value('used_on'))->toBe('2026-05-24')
        ->and(balanceOf($this->maya['id']))->toBe(1);
    assertLedgersMatchCaches($this->maya['id']);
});

it('never spends on an open period', function () {
    setAutoFreeze($this, $this->maya, true);
    dailyHabit($this, $this->maya);
    ($this->closeAt)('2026-05-21T06:59:00Z'); // 23:59 on 20 May, LA

    expect(usages($this->maya['id']))->toBe([])->and(balanceOf($this->maya['id']))->toBe(2);
});

it('does not protect misses from before opting in (A11, through the real mutation)', function () {
    $habit = dailyHabit($this, $this->maya);
    $this->freezeClock('2026-05-22T16:00:00Z');
    $ack = setAutoFreeze($this, $this->maya, true);
    ($this->closeAt)('2026-05-22T17:00:00Z');
    expect($ack['status'])->toBe('accepted')->and(usages($this->maya['id']))->toBe([]);

    ($this->closeAt)('2026-05-23T17:00:00Z');

    expect(usages($this->maya['id']))->toBe(["{$habit}:d:2026-05-22:active"])
        ->and(DB::table('user_freeze_policy_versions')->sole()->effective_at)->toStartWith('2026-05-22 16:00:00');
    assertLedgersMatchCaches($this->maya['id']);
});

it('stops spending once opted out', function () {
    setAutoFreeze($this, $this->maya, true);
    $this->freezeClock('2026-05-20T16:30:00Z');
    setAutoFreeze($this, $this->maya, false);
    dailyHabit($this, $this->maya);
    ($this->closeAt)('2026-05-23T17:00:00Z');

    expect(usages($this->maya['id']))->toBe([])
        ->and(balanceOf($this->maya['id']))->toBe(2)
        ->and(DB::table('user_freeze_policy_versions')->orderBy('effective_at')->pluck('enabled')->all())->toBe([true, false]);
});

it('refunds a protected day completed late: one at balance 1, a cap_reached audit at balance 2', function (bool $toppedUp) {
    setAutoFreeze($this, $this->maya, true);
    $habit = dailyHabit($this, $this->maya);
    ($this->closeAt)('2026-05-21T17:00:00Z');
    setAutoFreeze($this, $this->maya, false);
    if ($toppedUp) {
        ($this->closeAt)('2026-06-01T17:00:00Z');
    }
    expect(balanceOf($this->maya['id']))->toBe($toppedUp ? 2 : 1);

    $this->sync($this->maya['token'], [M::setValue($habit, 1, 0, '2026-05-20T18:00:00Z')])->assertJsonPath('data.acks.0.status', 'accepted');

    $refund = DB::table('freeze_ledger')->where('kind', 'refund')->sole();
    expect(balanceOf($this->maya['id']))->toBe(2)
        ->and("{$refund->reason}:{$refund->delta}")->toBe($toppedUp ? 'cap_reached:0' : 'late_completion:1')
        ->and($refund->source_key)->toBe("refund:{$habit}:d:2026-05-20")
        ->and(usages($this->maya['id']))->toBe(["{$habit}:d:2026-05-20:refunded"])
        ->and((bool) DB::table('period_evaluations')->where('period_key', 'd:2026-05-20')->value('completed'))->toBeTrue();

    // A second late edit never refunds again.
    $log = DB::table('habit_logs')->where('habit_id', $habit)->sole();
    $this->sync($this->maya['token'], [M::setValue($habit, 0, (int) $log->version, '2026-05-20T19:00:00Z', logId: $log->id)])->assertOk();
    $this->sync($this->maya['token'], [M::setValue($habit, 1, (int) $log->version + 1, '2026-05-20T19:30:00Z', logId: $log->id)])->assertOk();
    expect(DB::table('freeze_ledger')->where('kind', 'refund')->count())->toBe(1);
    assertLedgersMatchCaches($this->maya['id']);
})->with(['balance 1' => false, 'balance 2' => true]);
