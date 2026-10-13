<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A43: xp_delta on accepted log acks (contract-fixtures/sync/ack_xp_delta.json), kept in the
 * receipt, and next_refill_on on GET /freezes from the user's calendar.
 */

it('replays every ack_xp_delta.json case through /sync', function (array $case) {
    $fixture = syncFixtureFile('ack_xp_delta');
    $this->freezeClock($fixture['now']);
    $maya = $this->registerUser('Maya');
    $habit = (string) Str::uuid7();
    $this->sync($maya['token'], [M::habitCreate($habit, $fixture['habit']['type'], $fixture['habit']['target_value'], ['unit' => $fixture['habit']['unit']])])
        ->assertJsonPath('data.acks.0.status', 'accepted');
    $sent = [];

    foreach ($case['steps'] as $i => $step) {
        $log = DB::table('habit_logs')->where('habit_id', $habit)->first();
        $mutation = match (true) {
            isset($step['replay_of']) => $sent[$step['replay_of']],
            $step['operation'] === 'log.set_value' => M::setValue($habit, $step['value'], $log === null ? 0 : (int) $log->version, $fixture['now'], logId: $log?->id),
            $step['operation'] === 'log.delete' => M::delete((string) $log?->id, (int) $log?->version, $habit),
            default => [
                'mutation_id' => (string) Str::uuid7(), 'entity' => 'habit_log', 'entity_id' => (string) Str::uuid7(),
                'operation' => $step['operation'], 'base_version' => null, 'occurred_at' => $fixture['now'],
                'captured_timezone' => 'America/Los_Angeles', 'payload' => ['habit_id' => $habit, 'delta' => $step['delta']],
            ],
        };
        $sent[$i] = $mutation;

        $ack = $this->sync($maya['token'], [$mutation])->assertOk()->json('data.acks.0');

        expect([$ack['status'], $ack['duplicate']])->toBe([$step['expect']['status'], $step['expect']['duplicate']], "step {$i}");
        if ($step['expect']['xp_delta'] === null) {
            expect($ack)->not->toHaveKey('xp_delta');
        } else {
            expect($ack['xp_delta'] ?? null)->toBe($step['expect']['xp_delta'], "step {$i}");
        }
    }
})->with(function () {
    foreach (syncFixtureFile('ack_xp_delta')['cases'] as $case) {
        yield $case['name'] => [$case];
    }
});

it('gives no xp_delta for editing a day completed before Phase 5', function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya');
    $water = (string) Str::uuid7();
    $this->sync($maya['token'], [M::habitCreate($water, 'quantity', '2000.000', ['unit' => 'ml'])])->assertOk();
    $this->sync($maya['token'], [M::setValue($water, '2500.000', 0)])->assertOk();
    DB::table('xp_ledger')->delete();
    DB::table('xp_entitlements')->delete();
    $log = DB::table('habit_logs')->sole();

    $ack = $this->sync($maya['token'], [M::setValue($water, '3000.000', (int) $log->version, logId: $log->id)])->json('data.acks.0');

    expect($ack['status'])->toBe('accepted')->and($ack)->not->toHaveKey('xp_delta');
});

it('decodes a receipt stored before xp_delta existed', function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $maya = $this->registerUser('Maya');
    $water = (string) Str::uuid7();
    $this->sync($maya['token'], [M::habitCreate($water, 'quantity', '2000.000', ['unit' => 'ml'])])->assertOk();
    $mutation = M::setValue($water, '2000.000', 0);
    $this->sync($maya['token'], [$mutation])->assertJsonPath('data.acks.0.xp_delta', 10);
    $receipt = DB::table('mutation_receipts')->where('mutation_id', $mutation['mutation_id'])->sole();
    $old = json_decode((string) $receipt->result, true);
    unset($old['xp_delta']);
    DB::table('mutation_receipts')->where('mutation_id', $mutation['mutation_id'])->update(['result' => json_encode($old)]);

    $ack = $this->sync($maya['token'], [$mutation])->json('data.acks.0');

    expect([$ack['status'], $ack['duplicate']])->toBe(['accepted', true])->and($ack)->not->toHaveKey('xp_delta');
});

it('names the first day of the user\'s next local month as next_refill_on', function (string $instant, string $timezone, string $expected) {
    $this->freezeClock($instant);
    $user = $this->registerUser('Maya', timezone: $timezone);

    $data = $this->withToken($user['token'])->getJson('/api/v1/freezes')->assertOk()->json('data');

    expect($data['next_refill_on'])->toBe($expected);
})->with([
    'Los Angeles, late May' => ['2026-05-28T17:22:00Z', 'America/Los_Angeles', '2026-06-01'],
    'Los Angeles, December' => ['2026-12-15T17:00:00Z', 'America/Los_Angeles', '2027-01-01'],
    'Los Angeles, 31 May evening (1 June UTC)' => ['2026-06-01T03:00:00Z', 'America/Los_Angeles', '2026-06-01'],
    'Accra, the same instant' => ['2026-06-01T03:00:00Z', 'Africa/Accra', '2026-07-01'],
]);
