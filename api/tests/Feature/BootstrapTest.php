<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->user = $this->registerUser();
});

it('pages a consistent snapshot, then /sync from snapshot_seq delivers later changes (A2)', function () {
    $habits = [(string) Str::uuid7(), (string) Str::uuid7(), (string) Str::uuid7()];
    $mutations = array_map(fn ($h) => M::habitCreate($h, overrides: ['start_local_date' => '2026-05-25', 'date_mode' => 'backdate']), $habits);
    foreach ([25, 26, 27] as $day) {
        $mutations[] = M::setValue($habits[0], 1, 0, "2026-05-{$day}T18:00:00Z");
    }
    $acks = $this->sync($this->user['token'], $mutations)->json('data.acks');
    $this->sync($this->user['token'], [M::delete($acks[3]['entity_id'], 1, $habits[0])]);

    $pages = [];
    $cursor = null;
    do {
        $page = $this->bootstrapPage($this->user['token'], $cursor, 2)->json('data');
        $pages[] = $page;
        $cursor = $page['next_cursor'];
        if (count($pages) === 1) {
            // Another device writes while this one is bootstrapping.
            $late = $this->sync($this->user['token'], [M::setValue($habits[1], 1, 0, '2026-05-28T17:00:00Z')])->json('data.acks.0');
        }
    } while ($page['has_more']);

    $snapshot = $pages[0]['snapshot_seq'];
    expect($pages[0]['user']['id'])->toBe($this->user['id'])
        ->and(array_filter(array_column(array_slice($pages, 1), 'user')))->toBe([])
        ->and(array_unique(array_column($pages, 'snapshot_seq')))->toBe([$snapshot]);

    $allHabits = array_merge(...array_column($pages, 'habits'));
    $allLogs = array_merge(...array_column($pages, 'logs'));
    expect(collect($allHabits)->pluck('id')->sort()->values()->all())->toBe(collect($habits)->sort()->values()->all())
        ->and($allHabits[0]['definitions'])->toHaveCount(1)
        // Tombstones are included so the device can reconcile deletions.
        ->and(collect($allLogs)->whereNotNull('deleted_at')->count())->toBe(1)
        ->and(end($pages)['sync_cursor'])->not->toBeNull();

    // Continue from the pinned snapshot: everything after it arrives, including the late write.
    $delta = $this->sync($this->user['token'], cursor: end($pages)['sync_cursor'])->json('data.changes');
    expect(array_column($delta, 'seq'))->toBe(range($snapshot + 1, $snapshot + count($delta)))
        ->and(array_column($delta, 'id'))->toContain($late['entity_id']);
});

it('expires a bootstrap cursor from another account (A29)', function () {
    $other = $this->registerUser('Other');
    $this->sync($other['token'], [M::habitCreate((string) Str::uuid7()), M::habitCreate((string) Str::uuid7())]);
    $foreignCursor = $this->bootstrapPage($other['token'], null, 1)->json('data.next_cursor');

    $this->app['auth']->forgetGuards();
    $this->withToken($this->user['token'])->getJson('/api/v1/sync/bootstrap?cursor='.urlencode($foreignCursor))
        ->assertStatus(410)->assertJsonPath('error.code', 'cursor_expired');
});

it('validates the page size', function (string $limit) {
    $this->withToken($this->user['token'])->getJson('/api/v1/sync/bootstrap?limit='.$limit)->assertStatus(422);
})->with(['0', '501', 'abc']);
