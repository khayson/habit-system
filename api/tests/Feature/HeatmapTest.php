<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * GET /habits/{id}/heatmap (spec 06). Los Angeles account; 17:22Z on 28 May is 10:22 local.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->maya['token'], [
        M::habitCreate($this->habit, overrides: ['start_local_date' => '2026-05-26', 'date_mode' => 'backdate']),
        M::setValue($this->habit, 1, 0, '2026-05-26T18:00:00Z'),
    ])->assertOk();
});

function heatmap(object $test, string $token, string $habit, array $query): TestResponse
{
    app('auth')->forgetGuards();

    return $test->withToken($token)->getJson("/api/v1/habits/{$habit}/heatmap?".http_build_query($query));
}

it('gives every date a status with a text legend', function () {
    $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0, '2026-05-28T17:00:00Z')]);

    $data = heatmap($this, $this->maya['token'], $this->habit, ['from' => '2026-05-25', 'to' => '2026-05-29'])->assertOk()->json('data');

    expect(array_column($data['days'], 'status', 'date'))->toBe([
        '2026-05-25' => 'not_due',   // before the start
        '2026-05-26' => 'complete',
        '2026-05-27' => 'missed',
        '2026-05-28' => 'complete',  // today, already done
        '2026-05-29' => 'pending',   // future
    ])->and($data['today'])->toBe('2026-05-28')
        ->and(array_column($data['legend'], 'status'))->toBe(['complete', 'protected', 'missed', 'not_due', 'pending'])
        ->and(array_column($data['legend'], 'label'))->toBe(['Complete', 'Protected', 'Missed', 'Not due', 'Pending']);
});

it('shows today as still open until it is done', function () {
    $days = heatmap($this, $this->maya['token'], $this->habit, ['from' => '2026-05-28', 'to' => '2026-05-28'])->json('data.days');

    expect($days)->toBe([['date' => '2026-05-28', 'status' => 'pending']]);
});

it('closes stale periods before answering (lazy closer, A10)', function () {
    $this->freezeClock('2026-05-31T17:00:00Z');
    expect(DB::table('period_evaluations')->where('period_key', 'd:2026-05-30')->exists())->toBeFalse();

    $days = heatmap($this, $this->maya['token'], $this->habit, ['from' => '2026-05-29', 'to' => '2026-05-30'])->json('data.days');

    expect(array_column($days, 'status'))->toBe(['missed', 'missed'])
        ->and(DB::table('period_evaluations')->where('period_key', 'd:2026-05-30')->exists())->toBeTrue();
});

it('validates the window', function (array $query) {
    heatmap($this, $this->maya['token'], $this->habit, $query)
        ->assertStatus(422)->assertJsonPath('error.code', 'validation_failed');
})->with([
    'missing to' => [['from' => '2026-05-01']],
    'to before from' => [['from' => '2026-05-10', 'to' => '2026-05-01']],
    'not a date' => [['from' => '2026-5-1', 'to' => '2026-05-02']],
    '367 days' => [['from' => '2025-05-28', 'to' => '2026-05-29']],
]);

it('allows exactly 366 days', function () {
    $days = heatmap($this, $this->maya['token'], $this->habit, ['from' => '2025-05-28', 'to' => '2026-05-28'])->assertOk()->json('data.days');

    expect($days)->toHaveCount(366);
});

it('answers a foreign, missing or malformed habit id with the same 404', function () {
    $bob = $this->registerUser('Bob');
    $query = ['from' => '2026-05-25', 'to' => '2026-05-29'];

    $foreign = heatmap($this, $bob['token'], $this->habit, $query)->assertNotFound()->json('error');
    $missing = heatmap($this, $bob['token'], (string) Str::uuid7(), $query)->assertNotFound()->json('error');
    $malformed = heatmap($this, $bob['token'], 'not-a-uuid', $query)->assertNotFound()->json('error');

    expect($foreign)->toBe($missing)->and($missing)->toBe($malformed)
        ->and($foreign)->toBe(['code' => 'not_found', 'message' => 'Not found.']);
});

it('requires a session', function () {
    app('auth')->forgetGuards();
    $this->flushHeaders()->getJson("/api/v1/habits/{$this->habit}/heatmap?from=2026-05-25&to=2026-05-29")->assertUnauthorized();
});
