<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A31 + A32: derived entities in bootstrap (contract-fixtures/sync/bootstrap_entities.json).
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya');
    $this->habit = (string) Str::uuid7();
    $this->quiet = (string) Str::uuid7();
    $this->sync($this->maya['token'], [
        M::habitCreate($this->habit, overrides: ['start_local_date' => '2026-05-26', 'date_mode' => 'backdate']),
        M::habitCreate($this->quiet),
        M::setValue($this->habit, 1, 0, '2026-05-27T18:00:00Z'),
    ])->assertOk();
});

/** @return list<array<string, mixed>> every page of a bootstrap */
function bootstrapPages(object $test, string $token, int $limit): array
{
    $pages = [];
    $cursor = null;
    do {
        app('auth')->forgetGuards();
        $page = $test->withToken($token)->getJson('/api/v1/sync/bootstrap?'.http_build_query(array_filter(['limit' => $limit, 'cursor' => $cursor])))
            ->assertOk()->json('data');
        $pages[] = $page;
        $cursor = $page['next_cursor'];
    } while ($page['has_more']);

    return $pages;
}

it('carries habit_progress for every habit and recent evaluations in entities, matching the contract', function () {
    $pages = bootstrapPages($this, $this->maya['token'], 200);
    $fixture = syncFixtureFile('bootstrap_entities');

    $progressPage = collect($pages)->first(fn ($p) => ($p['entities'][0]['entity'] ?? null) === 'habit_progress');
    $evaluationPage = collect($pages)->last();
    // The contract pins one item of each kind (the logged habit, its 27 May period); a page may
    // hold more.
    $progressItem = collect($progressPage['entities'])->firstWhere('id', $this->habit);
    $evaluationItem = collect($evaluationPage['entities'])->firstWhere('payload.period_key', 'd:2026-05-27');
    assertMatchesContract($fixture['progress_page'], [...$progressPage, 'entities' => [$progressItem]]);
    assertMatchesContract($fixture['evaluation_page'], [...$evaluationPage, 'entities' => [$evaluationItem]]);

    $progress = collect($pages)->pluck('entities')->flatten(1)->where('entity', 'habit_progress');
    expect($progress->pluck('id')->sort()->values()->all())->toBe(collect([$this->habit, $this->quiet])->sort()->values()->all())
        ->and($progress->firstWhere('id', $this->habit)['payload']['current'])->toBe(1);

    $evaluations = collect($pages)->pluck('entities')->flatten(1)->where('entity', 'period_evaluation');
    expect($evaluations->pluck('payload.period_key')->all())->toBe(['d:2026-05-26', 'd:2026-05-27'])
        ->and($evaluations->pluck('version')->all())->toBe([1, 1]);
});

it('sends evaluations from the last 400 days only', function () {
    $old = DB::table('period_evaluations')->where('period_key', 'd:2026-05-26')->first();
    DB::table('period_evaluations')->insert([
        ...(array) $old,
        'id' => (string) Str::uuid7(),
        'period_key' => 'd:2025-04-01',
        'start_date' => '2025-04-01',
        'end_date' => '2025-04-01',
        'starts_at' => '2025-04-01 07:00:00+00',
        'ends_at' => '2025-04-02 07:00:00+00',
    ]);

    $keys = collect(bootstrapPages($this, $this->maya['token'], 200))->pluck('entities')->flatten(1)
        ->where('entity', 'period_evaluation')->pluck('payload.period_key')->all();

    expect($keys)->not->toContain('d:2025-04-01')
        ->and($keys)->toContain('d:2026-05-26');
});

it('pages through every entity exactly once with a small page size', function () {
    $entities = collect(bootstrapPages($this, $this->maya['token'], 1))->pluck('entities')->flatten(1);

    expect($entities->map(fn ($e) => $e['entity'].':'.$e['id'])->duplicates())->toBeEmpty()
        ->and($entities->where('entity', 'habit_progress'))->toHaveCount(2)
        ->and($entities->where('entity', 'period_evaluation'))->toHaveCount(2);
});

it('never shows one owner\'s derived entities to another', function () {
    $bob = $this->registerUser('Bob');

    $entities = collect(bootstrapPages($this, $bob['token'], 200))->pluck('entities')->flatten(1);

    expect($entities->pluck('id')->intersect([$this->habit, $this->quiet]))->toBeEmpty()
        ->and($entities->pluck('payload.habit_id')->intersect([$this->habit, $this->quiet]))->toBeEmpty();
});
