<?php

use App\Application\Periods\PeriodCloser;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * GET /rewards and GET /freezes (A39 to A42): contract-fixtures/rewards, owner-scoped, newest
 * first, keyset pages on (created_at, id). Los Angeles; 17:22Z on 28 May is 10:22.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($this->habit, overrides: ['start_local_date' => '2026-05-01', 'date_mode' => 'backdate'])])->assertJsonPath('data.acks.0.status', 'accepted');
});

function rewardsGet(object $test, string $token, string $path, array $query = []): TestResponse
{
    app('auth')->forgetGuards();

    return $test->withToken($token)->getJson("/api/v1/{$path}?".http_build_query($query));
}

/**
 * Completed habit-days from 1 Jan on, all written in the same instant so pages split on the id.
 * The cache moves with the ledger (invariant 7).
 */
function seedXp(string $userId, string $habitId, int $days): void
{
    for ($i = 0; $i < $days; $i++) {
        $id = (string) Str::uuid7();
        $at = '2026-05-01T00:00:00Z';
        DB::table('xp_entitlements')->insert(['id' => $id, 'user_id' => $userId, 'habit_id' => $habitId,
            'log_date' => date('Y-m-d', strtotime("2026-01-01 +{$i} days")), 'amount' => 10, 'state' => 'active', 'revision' => 1,
            'created_at' => $at, 'updated_at' => $at]);
        DB::table('xp_ledger')->insert(['id' => (string) Str::uuid7(), 'user_id' => $userId, 'entitlement_id' => $id,
            'entitlement_revision' => 1, 'delta' => 10, 'reason' => 'completion', 'mutation_id' => null, 'created_at' => $at]);
    }
    DB::table('users')->where('id', $userId)->increment('xp', 10 * $days);
}

it('answers GET /rewards in the contract shape, its numbers equal to reward_state', function () {
    $fixture = contractFixture('rewards/rewards_response.json');
    seedXp($this->maya['id'], $this->habit, 123);
    $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0)])->assertOk();

    $data = rewardsGet($this, $this->maya['token'], 'rewards', ['limit' => 1])->assertOk()->json('data');

    assertMatchesContract($fixture['response']['data'], $data);
    expect($data['next_cursor'])->not->toBeNull();
    assertLedgersMatchCaches($this->maya['id']);
});

it('answers GET /freezes in the contract shape, grants naming no habit', function () {
    $fixture = contractFixture('rewards/freezes_response.json')['response']['data'];
    $this->freezeClock('2026-05-27T16:00:00Z');
    $this->sync($this->maya['token'], [M::setAutoFreeze($this->maya['id'], true, (int) DB::table('users')->where('id', $this->maya['id'])->value('version'))]);
    $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0, '2026-05-26T17:00:00Z')])->assertOk();
    $this->freezeClock('2026-05-28T17:22:00Z');
    app(PeriodCloser::class)->closeUser($this->maya['id']);

    $data = rewardsGet($this, $this->maya['token'], 'freezes')->assertOk()->json('data');

    // Newest first: the spend, the May grant at the cap, then the signup grant.
    $ledger = $data['ledger'];
    assertMatchesContract([...$fixture, 'ledger' => [$fixture['ledger'][0]]], [...$data, 'ledger' => [$ledger[0]]]);
    assertMatchesContract($fixture['ledger'][1], end($ledger));
    expect(array_column($ledger, 'reason'))->toBe(['missed_period', 'cap_reached', 'signup'])
        ->and($ledger[0]['habit_id'])->toBe($this->habit)
        ->and($data['next_cursor'])->toBeNull();
    assertLedgersMatchCaches($this->maya['id']);
});

it('pages the XP ledger newest first over three pages, splitting ties on the id', function () {
    seedXp($this->maya['id'], $this->habit, 5);
    $all = DB::table('xp_ledger')->orderByDesc('created_at')->orderByDesc('id')->pluck('id')->all();

    $seen = [];
    $cursor = null;
    $sizes = [];
    do {
        $page = rewardsGet($this, $this->maya['token'], 'rewards', array_filter(['limit' => 2, 'cursor' => $cursor]))->assertOk()->json('data');
        $sizes[] = count($page['ledger']);
        array_push($seen, ...array_column($page['ledger'], 'id'));
        $cursor = $page['next_cursor'];
    } while ($cursor !== null);

    expect($sizes)->toBe([2, 2, 1])->and($seen)->toBe($all);
});

it('pages the freeze ledger over three pages', function () {
    app(PeriodCloser::class)->closeUser($this->maya['id']); // month:2026-05 at the cap
    $this->freezeClock('2026-06-01T17:00:00Z');
    app(PeriodCloser::class)->closeUser($this->maya['id']); // month:2026-06 at the cap
    $all = DB::table('freeze_ledger')->orderByDesc('created_at')->orderByDesc('id')->pluck('id')->all();

    $seen = [];
    $cursor = null;
    do {
        $page = rewardsGet($this, $this->maya['token'], 'freezes', array_filter(['limit' => 1, 'cursor' => $cursor]))->assertOk()->json('data');
        array_push($seen, ...array_column($page['ledger'], 'id'));
        $cursor = $page['next_cursor'];
    } while ($cursor !== null);

    expect($all)->toHaveCount(3)->and($seen)->toBe($all);
});

it('shows each owner only their own numbers and ledgers', function () {
    seedXp($this->maya['id'], $this->habit, 3);
    $bob = $this->registerUser('Bob');

    $rewards = rewardsGet($this, $bob['token'], 'rewards')->assertOk()->json('data');
    $freezes = rewardsGet($this, $bob['token'], 'freezes')->assertOk()->json('data');

    expect([$rewards['xp'], $rewards['ledger']])->toBe([0, []])
        ->and(array_column($freezes['ledger'], 'reason'))->toBe(['signup'])
        ->and(DB::table('freeze_ledger')->where('id', $freezes['ledger'][0]['id'])->value('user_id'))->toBe($bob['id']);
});

it('refuses a bad cursor or limit with 422', function (string $path, array $query) {
    seedXp($this->maya['id'], $this->habit, 3);
    $foreign = $this->registerUser('Bob');
    $mayaCursor = rewardsGet($this, $this->maya['token'], 'rewards', ['limit' => 1])->json('data.next_cursor');
    $query = array_map(fn ($v) => $v === 'MAYA' ? $mayaCursor : $v, $query);
    $token = ($query['as'] ?? null) === 'bob' ? $foreign['token'] : $this->maya['token'];
    unset($query['as']);

    rewardsGet($this, $token, $path, $query)->assertStatus(422)->assertJsonPath('error.code', 'validation_failed');
})->with([
    'garbage cursor' => ['rewards', ['cursor' => 'not-a-cursor']],
    'another endpoint\'s cursor' => ['freezes', ['cursor' => 'MAYA']],
    'another owner\'s cursor' => ['rewards', ['cursor' => 'MAYA', 'as' => 'bob']],
    'limit 0' => ['rewards', ['limit' => '0']],
    'limit 51' => ['freezes', ['limit' => '51']],
    'limit not a number' => ['rewards', ['limit' => 'ten']],
]);

it('accepts the largest limit', function () {
    seedXp($this->maya['id'], $this->habit, 60);

    expect(rewardsGet($this, $this->maya['token'], 'rewards', ['limit' => 50])->assertOk()->json('data.ledger'))->toHaveCount(50)
        ->and(rewardsGet($this, $this->maya['token'], 'rewards')->json('data.ledger'))->toHaveCount(20);
});
