<?php

use App\Application\Accounts\AccountPurger;
use App\Application\Exports\ExportBuilder;
use App\Application\Periods\PeriodCloser;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A51: habit.delete, against contract-fixtures/habit/habit_delete.json. A Los Angeles account; the
 * habit has check-ins (XP), a reminder, closed periods and a streak cache before it is deleted.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya Chen', 'maya@example.com');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->maya['token'], [
        M::habitCreate($this->habit, 'binary', 1, ['start_local_date' => '2026-05-20', 'date_mode' => 'backdate']),
        M::setValue($this->habit, 1, 0, '2026-05-21T18:00:00Z'),
        M::setValue($this->habit, 1, 0, '2026-05-28T17:00:00Z'),
        M::reminder('create', (string) Str::uuid7(), $this->habit),
    ])->assertOk();
    app(PeriodCloser::class)->closeUser($this->maya['id']);
});

function deleteFixture(): array
{
    return contractFixture('habit/habit_delete.json');
}

/** A habit.* mutation shaped like the fixture's delete. */
function habitDeleteOp(string $habitId, string $operation, ?int $baseVersion): array
{
    $m = deleteFixture()['delete']['mutation'];

    return [...$m, 'mutation_id' => (string) Str::uuid7(), 'entity_id' => $habitId, 'operation' => $operation, 'base_version' => $baseVersion];
}

function habitVersion(string $habitId): int
{
    return (int) DB::table('habits')->where('id', $habitId)->value('version');
}

function deleteHabit(object $test, string $token, string $habitId, ?int $base = null): TestResponse
{
    return $test->sync($token, [habitDeleteOp($habitId, 'habit.delete', $base ?? habitVersion($habitId))]);
}

/** @return array<string, int> rows the habit owns, by table */
function habitOwned(string $habitId): array
{
    $counts = [];
    foreach (['habit_logs', 'habit_definition_versions', 'habit_active_ranges', 'habit_streak_cache', 'period_evaluations'] as $table) {
        $counts[$table] = DB::table($table)->where('habit_id', $habitId)->count();
    }
    // Reminders stay as tombstones (6.6 review I1): only live ones count.
    $counts['reminders'] = DB::table('reminders')->where('habit_id', $habitId)->whereNull('deleted_at')->count();

    return $counts;
}

/** @return array<string, string> the kept ledgers, as JSON per table */
function keptLedgers(string $userId): array
{
    $kept = [];
    foreach (['xp_entitlements', 'xp_ledger', 'freeze_usage', 'freeze_ledger'] as $table) {
        $kept[$table] = DB::table($table)->where('user_id', $userId)->orderBy('id')->get()->toJson();
    }

    return $kept;
}

it('deletes: the fixture ack, a cleared tombstone, owned content gone, every ledger row and the level kept', function () {
    $fixture = deleteFixture();
    expect(array_filter(habitOwned($this->habit)))->toHaveCount(6);
    $ledgers = keptLedgers($this->maya['id']);
    $rewards = $this->withToken($this->maya['token'])->getJson('/api/v1/rewards')->json('data');
    expect((int) DB::table('users')->where('id', $this->maya['id'])->value('xp'))->toBeGreaterThan(0);

    $ack = deleteHabit($this, $this->maya['token'], $this->habit)->assertOk()->json('data.acks.0');

    $version = habitVersion($this->habit);
    assertMatchesContract([...$fixture['delete']['expect'], 'version' => $version], $ack);
    $row = DB::table('habits')->where('id', $this->habit)->first();
    expect([$row->name, $row->unit, $row->deleted_at === null])->toBe(['', null, false])
        ->and(array_filter(habitOwned($this->habit)))->toBe([])
        ->and(keptLedgers($this->maya['id']))->toBe($ledgers);
    app('auth')->forgetGuards();
    expect($this->withToken($this->maya['token'])->getJson('/api/v1/rewards')->json('data'))->toBe($rewards);
});

it('journals each removed log and reminder, then the habit tombstone in the fixture shape', function () {
    $fixture = deleteFixture();
    $before = (int) DB::table('users')->where('id', $this->maya['id'])->value('change_seq');
    deleteHabit($this, $this->maya['token'], $this->habit)->assertOk();

    $changes = DB::table('server_changes')->where('user_id', $this->maya['id'])->where('seq', '>', $before)->orderBy('seq')->get();
    $kinds = $changes->map(fn ($c) => ['entity' => $c->entity_type, 'operation' => $c->operation])->unique()->values()->all();
    expect($kinds)->toBe($fixture['journal'])
        ->and($changes->where('entity_type', 'habit_log')->count())->toBe(2)
        ->and($changes->pluck('seq')->map(fn ($s) => (int) $s)->all())->toBe(range($before + 1, $before + $changes->count()));

    app('auth')->forgetGuards();
    $pulled = collect($this->sync($this->maya['token'], cursor: null)->json('data.changes'))->where('entity', 'habit')->last();
    assertMatchesContract([...$fixture['tombstone'], 'version' => habitVersion($this->habit), 'payload' => [...$fixture['tombstone']['payload'], 'version' => habitVersion($this->habit), 'start_local_date' => '2026-05-20', 'category' => DB::table('habits')->where('id', $this->habit)->value('category')]], $pulled);
    $logTombstone = collect($this->sync($this->maya['token'], cursor: null)->json('data.changes'))->where('entity', 'habit_log')->last();
    expect($logTombstone['operation'])->toBe('delete')->and($logTombstone['payload']['deleted_at'])->not->toBeNull();
});

it('refuses a stale base_version with the current habit', function () {
    $stale = deleteFixture()['stale'];
    $ack = deleteHabit($this, $this->maya['token'], $this->habit, $stale['base_version'])->json('data.acks.0');

    expect([$ack['status'], $ack['error']['code'], $ack['error']['expected_version']])
        ->toBe([$stale['expect']['status'], $stale['expect']['error_code'], $stale['expect']['expected_version']])
        ->and($ack['error']['current']['id'])->toBe($this->habit)
        ->and(DB::table('habits')->where('id', $this->habit)->value('deleted_at'))->toBeNull();
});

it('acknowledges a repeated delete with no change', function () {
    deleteHabit($this, $this->maya['token'], $this->habit)->assertOk();
    $version = habitVersion($this->habit);
    $seq = (int) DB::table('users')->where('id', $this->maya['id'])->value('change_seq');

    $ack = deleteHabit($this, $this->maya['token'], $this->habit, 1)->json('data.acks.0');

    expect([$ack['status'], $ack['version']])->toBe(['accepted', $version])
        ->and(habitVersion($this->habit))->toBe($version)
        ->and((int) DB::table('users')->where('id', $this->maya['id'])->value('change_seq'))->toBe($seq);
});

it('deletes an archived habit too', function () {
    $this->sync($this->maya['token'], [habitDeleteOp($this->habit, 'habit.archive', habitVersion($this->habit))])->assertJsonPath('data.acks.0.status', 'accepted');
    deleteHabit($this, $this->maya['token'], $this->habit)->assertJsonPath('data.acks.0.status', 'accepted');
    expect(DB::table('habits')->where('id', $this->habit)->value('deleted_at'))->not->toBeNull();
});

it('rejects every later write: logs and reminders name the habit; habit writes name it as the resource', function () {
    $fixture = deleteFixture()['log_on_deleted'];
    deleteHabit($this, $this->maya['token'], $this->habit)->assertOk();
    $version = habitVersion($this->habit);
    $log = [...$fixture['mutation'], 'mutation_id' => (string) Str::uuid7(), 'entity_id' => (string) Str::uuid7(), 'payload' => ['habit_id' => $this->habit, 'value' => 1]];

    $ack = $this->sync($this->maya['token'], [$log])->json('data.acks.0');
    assertMatchesContract([...$fixture['expect'], 'error' => [...$fixture['expect']['error'], 'current_version' => $version]], $ack);
    expect($ack['entity_id'])->toBe($log['entity_id'])->and($ack['error']['habit_id'])->toBe($this->habit);

    foreach (['habit.update', 'habit.archive', 'habit.restore'] as $op) {
        $m = habitDeleteOp($this->habit, $op, $version);
        if ($op === 'habit.update') {
            $m['payload'] = ['name' => 'Back', 'category' => 'health', 'target_value' => 1, 'unit' => null, 'frequency_type' => 'daily', 'frequency_config' => []];
        }
        $a = $this->sync($this->maya['token'], [$m])->json('data.acks.0');
        expect([$a['status'], $a['error']['code'], $a['error']['resource_id']])->toBe(['conflict', 'resource_deleted', $this->habit], $op);
    }
    $reminder = $this->sync($this->maya['token'], [M::reminder('create', (string) Str::uuid7(), $this->habit)])->json('data.acks.0');
    expect([$reminder['status'], $reminder['error']['code'], $reminder['error']['entity']])->toBe(['conflict', 'resource_deleted', 'habit'])
        ->and(array_filter(habitOwned($this->habit)))->toBe([]);
});

it('is owner-scoped: another user cannot delete the habit', function () {
    $sam = $this->registerUser('Sam', 'sam@example.com');
    $ack = deleteHabit($this, $sam['token'], $this->habit)->json('data.acks.0');

    expect([$ack['status'], $ack['error']['code']])->toBe(['rejected', 'not_found'])
        ->and(DB::table('habits')->where('id', $this->habit)->value('deleted_at'))->toBeNull()
        ->and(array_filter(habitOwned($this->habit)))->toHaveCount(6);
});

it('is skipped by bootstrap, the heatmap, insights, exports and the period closer', function () {
    app('auth')->forgetGuards();
    $xpBefore = $this->withToken($this->maya['token'])->getJson('/api/v1/insights?period=month')->json('data.xp_earned');
    deleteHabit($this, $this->maya['token'], $this->habit)->assertOk();

    $cursor = null;
    $pages = '';
    do {
        $page = $this->bootstrapPage($this->maya['token'], $cursor, 100)->json('data');
        $pages .= json_encode([$page['habits'], $page['logs'], $page['entities']]);
        $cursor = $page['next_cursor'];
    } while ($page['has_more']);
    expect($pages)->not->toContain($this->habit);

    app('auth')->forgetGuards();
    $this->withToken($this->maya['token'])->getJson("/api/v1/habits/{$this->habit}/heatmap?from=2026-05-01&to=2026-05-28")->assertNotFound();
    app('auth')->forgetGuards();
    $insights = $this->withToken($this->maya['token'])->getJson('/api/v1/insights?period=month')->assertOk()->json('data');
    expect($insights['xp_earned'])->toBe($xpBefore)
        ->and($insights['totals']['eligible'])->toBe(0);

    $built = app(ExportBuilder::class)->build($this->maya['id'], 'json');
    $path = tempnam(sys_get_temp_dir(), 'zip');
    file_put_contents($path, $built['bytes']);
    $zip = new ZipArchive;
    $zip->open($path);
    $doc = json_decode((string) $zip->getFromName('export.json'), true);
    $zip->close();
    @unlink($path);
    expect(collect($doc['habits'])->pluck('id')->all())->not->toContain($this->habit)
        ->and(collect($doc['logs'])->pluck('habit_id')->all())->not->toContain($this->habit)
        ->and(collect($doc['xp_entitlements'])->pluck('habit_id')->all())->toContain($this->habit);

    $this->freezeClock('2026-05-30T17:00:00Z');
    app(PeriodCloser::class)->closeUser($this->maya['id']);
    expect(array_filter(habitOwned($this->habit)))->toBe([])
        ->and(app(PeriodCloser::class)->isStale($this->maya['id']))->toBeFalse();
});

it('leaves the purge working: the tombstone goes with the account', function () {
    deleteHabit($this, $this->maya['token'], $this->habit)->assertOk();
    Queue::fake();
    app('auth')->forgetGuards();
    $id = $this->withToken($this->maya['token'])->deleteJson('/api/v1/me', ['password' => 'correct horse battery staple'])->json('data.id');
    app(AccountPurger::class)->purge($id);

    expect(DB::table('habits')->where('id', $this->habit)->exists())->toBeFalse()
        ->and(DB::table('xp_entitlements')->where('habit_id', $this->habit)->exists())->toBeFalse();
});

// 6.6 review I1: a reminder edit after its habit was deleted names the habit, like log writes.
it('answers a reminder edit or delete under a deleted habit with resource_deleted naming the habit', function () {
    $reminder = DB::table('reminders')->where('habit_id', $this->habit)->first();
    deleteHabit($this, $this->maya['token'], $this->habit)->assertOk();

    foreach (['update', 'delete'] as $step) {
        $ack = $this->sync($this->maya['token'], [M::reminder($step, (string) $reminder->id, null, (int) $reminder->version)])->json('data.acks.0');
        expect([$ack['status'], $ack['error']['code'], $ack['error']['entity'], $ack['error']['habit_id']])
            ->toBe(['conflict', 'resource_deleted', 'habit', $this->habit], $step)
            ->and($ack['entity_id'])->toBe((string) $reminder->id);
    }
    expect(DB::table('reminders')->where('habit_id', $this->habit)->whereNull('deleted_at')->count())->toBe(0);
});
