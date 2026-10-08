<?php

use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * contract-fixtures/sync/log_backdate_payload.json: the mutation the app's "Save past check-in"
 * sends (screen 13), exactly as the Dart writer builds it, is accepted and filed under log_date.
 */

it('accepts the past check-in the app sends and files it under log_date', function () {
    $fixture = syncFixtureFile('log_backdate_payload');
    $this->freezeClock($fixture['now']);
    $maya = $this->registerUser('Maya');
    $habit = (string) Str::uuid7();
    $this->sync($maya['token'], [M::habitCreate($habit, overrides: [
        'start_local_date' => $fixture['habit_start_local_date'], 'date_mode' => 'backdate',
    ], occurredAt: $fixture['now'])])->assertJsonPath('data.acks.0.status', 'accepted');

    $mutation = $fixture['mutation'];
    $mutation['mutation_id'] = (string) Str::uuid7();
    $mutation['entity_id'] = (string) Str::uuid7();
    $mutation['payload']['habit_id'] = $habit;

    $ack = $this->sync($maya['token'], [$mutation])->json('data.acks.0');

    assertMatchesContract($fixture['expect'], $ack);
    expect($ack['entity_id'])->toBe($mutation['entity_id']);
    $row = DB::table('habit_logs')->where('id', $mutation['entity_id'])->first();
    expect($row->log_date)->toBe($fixture['mutation']['payload']['log_date'])
        ->and(CarbonImmutable::parse($row->occurred_at)->toIso8601ZuluString())->toBe($fixture['now']);
});
