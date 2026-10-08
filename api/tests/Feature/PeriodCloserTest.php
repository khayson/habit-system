<?php

use App\Application\Calendar\UserCalendar;
use App\Application\Periods\PeriodCloser;
use App\Jobs\ClosePeriodsJob;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A10 / A32: PeriodCloser, the streak cache and the derived entities.
 * The account lives in America/Los_Angeles; 17:22Z on 28 May is 10:22 local.
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($this->habit, overrides: ['start_local_date' => '2026-05-26', 'date_mode' => 'backdate'])])
        ->assertOk();
});

function evaluationRows(string $habitId): array
{
    return DB::table('period_evaluations')->where('habit_id', $habitId)->orderBy('period_key')
        ->get(['period_key', 'completed', 'revision'])
        ->map(fn ($r) => [$r->period_key, (bool) $r->completed, (int) $r->revision])->all();
}

function journalRows(string $userId, ?int $after = 0): array
{
    return DB::table('server_changes')->where('user_id', $userId)->where('seq', '>', $after)->orderBy('seq')
        ->get(['seq', 'entity_type', 'version'])->map(fn ($r) => [(int) $r->seq, $r->entity_type, (int) $r->version])->all();
}

function seqHead(string $userId): int
{
    return (int) DB::table('users')->where('id', $userId)->value('change_seq');
}

it('closes finished days at the boundary and publishes them as derived entities', function () {
    $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0, '2026-05-26T18:00:00Z')])->assertOk();
    $this->freezeClock('2026-05-30T17:00:00Z'); // 10:00 on 30 May in Los Angeles

    Artisan::call('habits:close-periods', ['--sync' => true]);

    expect(evaluationRows($this->habit))->toBe([
        ['d:2026-05-26', true, 1],
        ['d:2026-05-27', false, 1],
        ['d:2026-05-28', false, 1],
        ['d:2026-05-29', false, 1],
    ]);
    $progress = DB::table('habit_streak_cache')->where('habit_id', $this->habit)->first();
    expect([(int) $progress->current, (int) $progress->longest, $progress->computed_through, $progress->dirty_from])
        ->toBe([0, 1, '2026-05-29', null]);

    $changes = collect($this->sync($this->maya['token'])->json('data.changes'));
    $latest = $changes->where('entity', 'habit_progress')->last();
    expect($latest['id'])->toBe($this->habit)
        ->and($latest['version'])->toBe((int) $progress->version)
        ->and($latest['payload'])->toEqual(['habit_id' => $this->habit, 'current' => 0, 'longest' => 1, 'unit' => 'days', 'computed_through' => '2026-05-29']);
    expect($changes->where('entity', 'period_evaluation')->pluck('payload.period_key')->unique()->values()->all())
        ->toBe(['d:2026-05-26', 'd:2026-05-27', 'd:2026-05-28', 'd:2026-05-29']);
});

it('is idempotent: a second run with unchanged input writes and journals nothing', function () {
    $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0, '2026-05-26T18:00:00Z')]);
    $this->freezeClock('2026-05-30T17:00:00Z');
    $closer = app(PeriodCloser::class);
    $closer->closeUser($this->maya['id']);
    $before = [seqHead($this->maya['id']), evaluationRows($this->habit), DB::table('habit_streak_cache')->value('version')];

    expect($closer->closeUser($this->maya['id']))->toBe(0)
        ->and([seqHead($this->maya['id']), evaluationRows($this->habit), DB::table('habit_streak_cache')->value('version')])->toBe($before)
        ->and($closer->isStale($this->maya['id']))->toBeFalse();
});

it('re-evaluates a closed day after a late offline log, with a new revision in the log\'s transaction', function () {
    $this->freezeClock('2026-05-30T17:00:00Z');
    app(PeriodCloser::class)->closeUser($this->maya['id']);
    expect(evaluationRows($this->habit)[1])->toBe(['d:2026-05-27', false, 1]);
    $before = seqHead($this->maya['id']);

    // A phone that was offline on 27 May finally syncs its check-in.
    $ack = $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0, '2026-05-27T18:00:00Z')])->json('data.acks.0');

    expect($ack['status'])->toBe('accepted')
        ->and(evaluationRows($this->habit)[1])->toBe(['d:2026-05-27', true, 2]);
    $evaluationId = DB::table('period_evaluations')->where('period_key', 'd:2026-05-27')->value('id');
    // One commit, in order: the log, its period's new revision, the streak.
    expect(journalRows($this->maya['id'], $before))->toBe([
        [$before + 1, 'habit_log', 1],
        [$before + 2, 'period_evaluation', 2],
        [$before + 3, 'habit_progress', (int) DB::table('habit_streak_cache')->value('version')],
    ]);
    expect(DB::table('server_changes')->where('seq', $before + 2)->value('entity_id'))->toBe($evaluationId);
});

it('writes nothing at all when the derived write fails: the log and its entities share one transaction', function () {
    $this->freezeClock('2026-05-30T17:00:00Z');
    app(PeriodCloser::class)->closeUser($this->maya['id']);
    $before = [seqHead($this->maya['id']), evaluationRows($this->habit), DB::table('habit_logs')->count()];
    Event::listen(QueryExecuted::class, function (QueryExecuted $q) {
        if (str_contains($q->sql, 'insert into "server_changes"') && in_array('habit_progress', $q->bindings, true)) {
            throw new RuntimeException('crash while journaling habit_progress');
        }
    });

    $ack = $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0, '2026-05-27T18:00:00Z')])->json('data.acks.0');

    expect($ack['error']['code'])->toBe('server_error')
        ->and([seqHead($this->maya['id']), evaluationRows($this->habit), DB::table('habit_logs')->count()])->toBe($before);
});

it('leaves no partial state when a run dies mid-way, and the next run completes it', function () {
    $second = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($second, overrides: ['start_local_date' => '2026-05-26', 'date_mode' => 'backdate'])]);
    $this->freezeClock('2026-05-30T17:00:00Z');
    $closer = app(PeriodCloser::class);
    $before = [seqHead($this->maya['id']), DB::table('period_evaluations')->count(), DB::table('habit_streak_cache')->get()->toArray()];

    expect(fn () => $closer->closeUser($this->maya['id'], function (string $habitId) {
        throw new RuntimeException("worker killed after {$habitId}");
    }))->toThrow(RuntimeException::class);
    expect([seqHead($this->maya['id']), DB::table('period_evaluations')->count(), DB::table('habit_streak_cache')->get()->toArray()])
        ->toBe($before, 'the first habit\'s work rolled back too');

    expect($closer->closeUser($this->maya['id']))->toBeGreaterThan(0);
    expect(DB::table('period_evaluations')->count())->toBe(8);
});

it('journals the user again when a pending calendar change comes into force', function () {
    $this->sync($this->maya['token'], [M::setTimezone($this->maya['id'], 'Europe/Paris', 1)]);
    $this->freezeClock('2026-05-29T07:30:00Z');

    Artisan::call('habits:close-periods', ['--sync' => true]);

    $user = collect($this->sync($this->maya['token'])->json('data.changes'))->where('entity', 'user')->last();
    expect($user['version'])->toBe(3)
        ->and($user['payload']['timezone'])->toBe('Europe/Paris');
    expect(DB::table('users')->where('id', $this->maya['id'])->value('timezone'))->toBe('Europe/Paris');
});

it('queues one unique job per stale user, and none when everyone is up to date', function () {
    $bob = $this->registerUser('Bob');
    $this->sync($bob['token'], [M::habitCreate((string) Str::uuid7())]);
    $this->registerUser('Nobody'); // no habits: nothing to close, never queued
    $this->freezeClock('2026-05-30T17:00:00Z');
    Queue::fake();

    Artisan::call('habits:close-periods');
    Queue::assertPushed(ClosePeriodsJob::class, 2);

    foreach (DB::table('users')->pluck('id') as $id) {
        app(PeriodCloser::class)->closeUser((string) $id);
    }
    Queue::fake();
    Artisan::call('habits:close-periods');
    Queue::assertNothingPushed();
});

it('refuses mutations on derived entities with one answer for own, foreign and missing ids', function () {
    $this->sync($this->maya['token'], [M::setValue($this->habit, 1, 0, '2026-05-26T18:00:00Z')]);
    $bob = $this->registerUser('Bob');
    $bobHabit = (string) Str::uuid7();
    $this->sync($bob['token'], [M::habitCreate($bobHabit)]);
    $evaluationId = (string) DB::table('period_evaluations')->value('id');
    $mutation = fn (string $entity, string $id) => [
        'mutation_id' => (string) Str::uuid7(), 'entity' => $entity, 'entity_id' => $id,
        'operation' => 'progress.set', 'base_version' => 1, 'occurred_at' => '2026-05-28T17:20:00Z',
        'payload' => ['current' => 99],
    ];

    $acks = $this->sync($this->maya['token'], [
        $mutation('habit_progress', $this->habit),
        $mutation('habit_progress', $bobHabit),
        $mutation('habit_progress', (string) Str::uuid7()),
        $mutation('period_evaluation', $evaluationId),
        $mutation('period_evaluation', (string) Str::uuid7()),
    ])->json('data.acks');

    foreach ($acks as $ack) {
        expect($ack['status'])->toBe('rejected')
            ->and($ack['error'])->toBe(['code' => 'entity_read_only', 'message' => 'This is calculated by the server and cannot be changed.']);
    }
    expect(DB::table('habit_streak_cache')->where('habit_id', $this->habit)->value('current'))->not->toBe(99);
});

it('refreshes a habit in a fixed number of queries, however long its history (H2)', function () {
    $closer = app(PeriodCloser::class);
    $habitWith = function (int $days): string {
        $id = (string) Str::uuid7();
        $this->sync($this->maya['token'], [M::habitCreate($id)])->assertOk();
        // Longer than the API's 30-day backdate allows: set the history up directly.
        $start = (new DateTimeImmutable('2026-05-28'))->modify("-{$days} days")->format('Y-m-d');
        DB::table('habits')->where('id', $id)->update(['start_local_date' => $start]);
        DB::table('habit_definition_versions')->where('habit_id', $id)->update(['effective_date' => $start]);
        DB::table('habit_active_ranges')->where('habit_id', $id)->update(['starts_on' => $start]);

        return $id;
    };
    $count = 0;
    DB::listen(function () use (&$count) {
        $count++;
    });
    $queries = function (string $habitId) use ($closer, &$count): int {
        $habit = DB::table('habits')->where('id', $habitId)->first();
        $timeline = UserCalendar::timeline($this->maya['id']);
        $count = 0;
        DB::transaction(fn () => $closer->refreshHabit($this->maya['id'], $habit, $timeline));

        return $count;
    };
    $short = $habitWith(30);
    $long = $habitWith(1000);
    $closer->closeUser($this->maya['id']); // first run stores every closed day
    expect(DB::table('period_evaluations')->where('habit_id', $long)->count())->toBe(1000);

    $shortCount = $queries($short);
    $longCount = $queries($long);

    expect($longCount)->toBe($shortCount)
        ->and($shortCount)->toBeLessThanOrEqual(5);
});

it('never blocks a user for long when a worker dies (H3)', function () {
    expect((new ClosePeriodsJob($this->maya['id']))->uniqueFor)->toBe(600);

    $event = collect(app(Schedule::class)->events())
        ->first(fn ($e) => str_contains((string) $e->command, 'habits:close-periods'));
    expect($event)->not->toBeNull()
        ->and($event->withoutOverlapping)->toBeTrue()
        ->and($event->expiresAt)->toBe(10)
        ->and($event->expression)->toBe('*/5 * * * *');

    Log::spy();
    (new ClosePeriodsJob($this->maya['id']))->failed(new RuntimeException('secret detail'));
    Log::shouldHaveReceived('warning')->once()
        ->with('ClosePeriodsJob failed', ['user_id' => $this->maya['id']]);
});
