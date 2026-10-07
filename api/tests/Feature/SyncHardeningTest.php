<?php

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Exceptions;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * Phase 2a.1 (docs/reviews/PHASE_2A_REVIEW.md, A29). Ack shapes are checked against
 * contract-fixtures/sync/.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->user = $this->registerUser();
    $this->habit = (string) Str::uuid7();
});

function syncFixture(string $name): array
{
    return json_decode((string) file_get_contents(contractFixturePath("sync/{$name}.json")), true, flags: JSON_THROW_ON_ERROR);
}

// B1 ------------------------------------------------------------------------------------------

it('turns an unexpected failure in one mutation into a retryable ack; the batch continues (B1)', function () {
    Exceptions::fake();
    // Make the database fail for one specific habit, as an unforeseen bug would.
    DB::unprepared(<<<'SQL'
        CREATE FUNCTION boom() RETURNS trigger AS $$
        BEGIN
          IF NEW.name = 'BOOM' THEN RAISE EXCEPTION 'simulated failure'; END IF;
          RETURN NEW;
        END $$ LANGUAGE plpgsql;
        CREATE TRIGGER boom BEFORE INSERT ON habits FOR EACH ROW EXECUTE FUNCTION boom();
        SQL);
    $poison = M::habitCreate((string) Str::uuid7(), overrides: ['name' => 'BOOM']);

    $response = $this->sync($this->user['token'], [M::habitCreate($this->habit), $poison, M::habitCreate((string) Str::uuid7())]);

    $response->assertOk();
    $acks = $response->json('data.acks');
    expect(array_column($acks, 'status'))->toBe(['accepted', 'rejected', 'accepted']);
    assertMatchesContract(syncFixture('ack_server_error')['expect'], $acks[1]);
    expect(DB::table('mutation_receipts')->where('mutation_id', $poison['mutation_id'])->exists())->toBeFalse()
        ->and(DB::table('habits')->count())->toBe(2);
    Exceptions::assertReported(fn (QueryException $e) => str_contains($e->getMessage(), 'simulated failure'));

    // No receipt was stored, so once the cause is gone the same mutation is accepted.
    DB::unprepared('DROP TRIGGER boom ON habits; DROP FUNCTION boom();');
    $this->sync($this->user['token'], [$poison])->assertJsonPath('data.acks.0.status', 'accepted');
});

it('rejects out-of-range and malformed values in the ack, never with a 500 (B1)', function (string $type, mixed $value) {
    $habit = (string) Str::uuid7();
    $target = match ($type) {
        'binary' => 1,
        'quantity' => '1.000',
        default => 60,
    };
    $headers = ['X-Capabilities' => 'type.binary, type.quantity, type.duration'];
    $this->sync($this->user['token'], [M::habitCreate($habit, $type, $target, ['unit' => $type === 'quantity' ? 'mL' : null])], headers: $headers)
        ->assertJsonPath('data.acks.0.status', 'accepted');

    $this->sync($this->user['token'], [M::setValue($habit, $value, 0)])
        ->assertOk()
        ->assertJsonPath('data.acks.0.status', 'rejected')
        ->assertJsonPath('data.acks.0.error.code', 'invalid_value');
})->with([
    'quantity above numeric(12,3)' => ['quantity', '9999999999.000'],
    'quantity with 4 decimals' => ['quantity', '1.0001'],
    'quantity as a float' => ['quantity', 250.5],
    'duration over 25 hours' => ['duration', 100000],
    'negative duration' => ['duration', -1],
    'binary 2' => ['binary', 2],
]);

it('caps one mutation at 16 KB and 8 levels (A29)', function () {
    $big = M::habitCreate((string) Str::uuid7(), overrides: ['frequency_config' => ['pad' => str_repeat('x', 17000)]]);
    $deep = M::setValue($this->habit, 1, 0);
    $deep['payload']['detail'] = ['a' => ['b' => ['c' => ['d' => ['e' => ['f' => ['g' => 1]]]]]]];

    $acks = $this->sync($this->user['token'], [$big, $deep])->assertOk()->json('data.acks');

    expect($acks[0]['error']['code'])->toBe('payload_too_large')
        ->and($acks[1]['error']['code'])->toBe('validation_failed')
        ->and($acks[1]['error']['fields'])->toHaveKey('payload');
});

it('rejects over-long strings in the ack (B1)', function () {
    $acks = $this->sync($this->user['token'], [
        M::habitCreate((string) Str::uuid7(), overrides: ['name' => str_repeat('n', 101)]),
        M::habitCreate((string) Str::uuid7(), overrides: ['unit' => str_repeat('u', 25), 'type' => 'quantity', 'target_value' => '1.000']),
    ])->json('data.acks');

    expect($acks[0]['error']['fields'])->toHaveKey('name')
        ->and($acks[1]['error']['fields'])->toHaveKey('unit');
});
