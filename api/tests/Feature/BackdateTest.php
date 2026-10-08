<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Explicit log backdate (spec 08) near local midnight in a non-UTC zone. At 06:50Z on 28 May it
 * is 23:50 on 27 May in Los Angeles: UTC already says 28 May, the user's day does not.
 */

const BACKDATE_NOW = '2026-05-28T06:50:00Z';

beforeEach(function () {
    $this->freezeClock(BACKDATE_NOW);
    $this->maya = $this->registerUser('Maya');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($this->habit, overrides: ['start_local_date' => '2026-04-27', 'date_mode' => 'backdate'], occurredAt: BACKDATE_NOW)])
        ->assertJsonPath('data.acks.0.status', 'accepted');
});

function backdated(string $habitId, string $date, string $occurredAt = BACKDATE_NOW): array
{
    $mutation = M::setValue($habitId, 1, 0, $occurredAt);
    $mutation['payload'] += ['date_mode' => 'backdate', 'log_date' => $date];

    return $mutation;
}

it('accepts day 30 and local today, rejects day 31 and local tomorrow', function (string $date, string $expected) {
    $ack = $this->sync($this->maya['token'], [backdated($this->habit, $date)])->json('data.acks.0');

    if ($expected === 'accepted') {
        expect($ack['status'])->toBe('accepted')
            ->and($ack['resolved_date'])->toBe($date)
            ->and(DB::table('habit_logs')->where('habit_id', $this->habit)->value('log_date'))->toBe($date);
    } else {
        expect($ack['status'])->toBe('rejected')
            ->and($ack['error']['code'])->toBe($expected)
            ->and(DB::table('habit_logs')->count())->toBe(0);
    }
})->with([
    'day 30 back' => ['2026-04-27', 'accepted'],
    'day 31 back' => ['2026-04-26', 'backdate_too_old'],
    'local today (UTC tomorrow)' => ['2026-05-27', 'accepted'],
    'local tomorrow (UTC today)' => ['2026-05-28', 'backdate_future'],
]);

it('checks against local today at occurred_at, not at receipt', function () {
    // Saved offline at 23:30 on 26 May local, synced later: it cannot claim 27 May.
    $ack = $this->sync($this->maya['token'], [backdated($this->habit, '2026-05-27', '2026-05-27T06:30:00Z')])->json('data.acks.0');

    expect($ack['error']['code'])->toBe('backdate_future');
});

it('keeps occurred_at bounded and requires the claimed date', function () {
    // occurred_at more than 5 minutes ahead of the server is refused even in backdate mode.
    $future = $this->sync($this->maya['token'], [backdated($this->habit, '2026-05-20', '2026-05-28T07:00:00Z')])->json('data.acks.0');
    expect($future['error']['code'])->toBe('future_event');

    $missingDate = M::setValue($this->habit, 1, 0, BACKDATE_NOW);
    $missingDate['payload']['date_mode'] = 'backdate';
    $ack = $this->sync($this->maya['token'], [$missingDate])->json('data.acks.0');
    expect($ack['error']['code'])->toBe('validation_failed')
        ->and($ack['error']['fields'])->toHaveKey('log_date');
});

it('re-evaluates the backdated closed day in the same transaction', function () {
    $this->sync($this->maya['token'], [backdated($this->habit, '2026-05-20')])->assertOk();

    expect(DB::table('period_evaluations')->where('period_key', 'd:2026-05-20')->value('completed'))->toBeTrue();
});
