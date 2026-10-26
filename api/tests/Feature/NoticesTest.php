<?php

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

/*
 * A57: notices Khay Studios publishes with artisan, read by the app from GET /notices. The same
 * for every account, plain text, active at server time, newest first, at most five.
 */

/** Publishes a notice through the command, as Khay Studios would. */
function publishNotice(string $title, string $body, ?string $starts = null, ?string $ends = null): int
{
    return Artisan::call('notices:publish', array_filter([
        '--title' => $title,
        '--body' => $body,
        '--starts' => $starts,
        '--ends' => $ends,
    ], fn ($v) => $v !== null));
}

/**
 * GET /notices as [$user]; the test client caches the first signed-in user, so forget it.
 *
 * @param  array{token: string}  $user
 * @return list<array<string, mixed>>
 */
function noticesFor(object $test, array $user): array
{
    app('auth')->forgetGuards();

    return $test->withToken($user['token'])->getJson('/api/v1/notices')->assertOk()->json('data');
}

it('needs a signed-in account', function () {
    $this->getJson('/api/v1/notices')->assertUnauthorized();
});

it('answers the fixture shape: active notices, newest first', function () {
    $this->freezeClock('2026-10-26T10:00:00Z');
    $fixture = contractFixture('notices/notices_response.json');
    [$first, $second] = $fixture['body']['data'];
    publishNotice($second['title'], $second['body'], '2026-10-20T09:00:00Z');
    publishNotice($first['title'], $first['body'], '2026-10-25T09:00:00Z', '2026-11-01T00:00:00Z');
    $user = $this->registerUser();

    $response = $this->withToken($user['token'])->getJson('/api/v1/notices')->assertOk();

    assertMatchesContract($fixture['body']['data'], $response->json('data'));
    expect($response->json('data.0.title'))->toBe($first['title'])
        ->and($response->json('data.0.ends_at'))->toBe('2026-11-01T00:00:00Z')
        ->and($response->json('data.1.ends_at'))->toBeNull();
});

it('leaves out notices not started yet and ended ones; the end is exclusive', function () {
    $this->freezeClock('2026-10-26T10:00:00Z');
    publishNotice('Later', 'Starts tomorrow.', '2026-10-27T00:00:00Z');
    publishNotice('Over', 'Ended exactly now.', '2026-10-01T00:00:00Z', '2026-10-26T10:00:00Z');
    publishNotice('Now', 'Active.', '2026-10-26T10:00:00Z');
    $user = $this->registerUser();

    $titles = collect($this->withToken($user['token'])->getJson('/api/v1/notices')->json('data'))->pluck('title');

    expect($titles->all())->toBe(['Now']);
});

it('sends at most five', function () {
    $this->freezeClock('2026-10-26T10:00:00Z');
    foreach (range(1, 7) as $i) {
        publishNotice("Notice {$i}", 'Body.', sprintf('2026-10-%02dT00:00:00Z', 10 + $i));
    }
    $user = $this->registerUser();

    $titles = collect($this->withToken($user['token'])->getJson('/api/v1/notices')->json('data'))->pluck('title');

    expect($titles->all())->toBe(['Notice 7', 'Notice 6', 'Notice 5', 'Notice 4', 'Notice 3']);
});

it('is the same for every account', function () {
    $this->freezeClock('2026-10-26T10:00:00Z');
    publishNotice('Hello', 'For everyone.');
    $maya = $this->registerUser('Maya', 'maya@example.test');
    $kofi = $this->registerUser('Kofi', 'kofi@example.test');

    expect(noticesFor($this, $maya))->toBe(noticesFor($this, $kofi));
});

it('publish starts now by default; list shows it; retire ends it now', function () {
    $this->freezeClock('2026-10-26T10:00:00Z');
    expect(publishNotice('Hello', 'Body.'))->toBe(0);
    $id = (string) DB::table('notices')->value('id');
    expect(DB::table('notices')->value('starts_at'))->toStartWith('2026-10-26 10:00:00');

    expect(Artisan::call('notices:list'))->toBe(0)
        ->and(Artisan::output())->toContain($id)->toContain('Hello');

    $this->freezeClock('2026-10-26T11:00:00Z');
    expect(Artisan::call('notices:retire', ['id' => $id]))->toBe(0);
    $user = $this->registerUser();
    expect($this->withToken($user['token'])->getJson('/api/v1/notices')->json('data'))->toBe([]);
});

it('publish refuses an empty or too long title or body, and an end before the start', function (array $options) {
    $this->freezeClock('2026-10-26T10:00:00Z');
    expect(Artisan::call('notices:publish', $options))->toBe(1)
        ->and(DB::table('notices')->count())->toBe(0);
})->with([
    'no title' => [['--title' => '', '--body' => 'Body.']],
    'long title' => [['--title' => str_repeat('a', 61), '--body' => 'Body.']],
    'no body' => [['--title' => 'Title', '--body' => '']],
    'long body' => [['--title' => 'Title', '--body' => str_repeat('a', 281)]],
    'end first' => [['--title' => 'Title', '--body' => 'Body.', '--ends' => '2026-10-26T09:00:00Z']],
    'bad date' => [['--title' => 'Title', '--body' => 'Body.', '--starts' => 'tomorrow-ish']],
]);

it('retire of an unknown id fails and changes nothing', function () {
    expect(Artisan::call('notices:retire', ['id' => '01900000-0000-7000-8000-000000000000']))->toBe(1);
});

it('the table refuses bad rows itself (CHECK constraints)', function (array $row) {
    expect(fn () => DB::table('notices')->insert([
        'id' => '01900000-0000-7000-8000-000000000001',
        'title' => 'Title', 'body' => 'Body.',
        'starts_at' => '2026-10-26 10:00:00+00', 'ends_at' => null,
        'created_at' => '2026-10-26 10:00:00+00',
        ...$row,
    ]))->toThrow(QueryException::class);
})->with([
    'empty title' => [['title' => '']],
    'long title' => [['title' => str_repeat('a', 61)]],
    'empty body' => [['body' => '']],
    'long body' => [['body' => str_repeat('a', 281)]],
    'end not after start' => [['ends_at' => '2026-10-26 10:00:00+00']],
]);

it('a notice for chosen people reaches only them; everyone notices still reach all', function () {
    $this->freezeClock('2026-10-26T10:00:00Z');
    $maya = $this->registerUser('Maya', 'maya@example.test');
    $kofi = $this->registerUser('Kofi', 'kofi@example.test');
    $ama = $this->registerUser('Ama', 'ama@example.test');
    publishNotice('For all', 'Everyone sees this.', '2026-10-25T00:00:00Z');
    expect(Artisan::call('notices:publish', [
        '--title' => 'Just for you', '--body' => 'Thanks for the bug report.',
        '--to' => ['Maya@Example.test', 'kofi@example.test'],
    ]))->toBe(0);

    $titles = fn (array $user) => collect(noticesFor($this, $user))->pluck('title')->all();

    expect($titles($maya))->toBe(['Just for you', 'For all'])
        ->and($titles($kofi))->toBe(['Just for you', 'For all'])
        ->and($titles($ama))->toBe(['For all']);
    expect(Artisan::call('notices:list'))->toBe(0)
        ->and(Artisan::output())->toContain('2 people')->toContain('everyone');
});

it('an unknown email stops the publish; nothing is written', function () {
    $this->registerUser('Maya', 'maya@example.test');
    expect(Artisan::call('notices:publish', [
        '--title' => 'Hi', '--body' => 'Body.', '--to' => ['maya@example.test', 'nobody@example.test'],
    ]))->toBe(1)
        ->and(Artisan::output())->toContain('nobody@example.test')
        ->and(DB::table('notices')->count())->toBe(0)
        ->and(DB::table('notice_recipients')->count())->toBe(0);
});

it('a targeted notice never falls back to everyone when its people are gone', function () {
    $this->freezeClock('2026-10-26T10:00:00Z');
    $maya = $this->registerUser('Maya', 'maya@example.test');
    $kofi = $this->registerUser('Kofi', 'kofi@example.test');
    Artisan::call('notices:publish', ['--title' => 'Hi', '--body' => 'Body.', '--to' => ['maya@example.test']]);
    DB::table('notice_recipients')->delete();

    expect(noticesFor($this, $kofi))->toBe([])
        ->and(noticesFor($this, $maya))->toBe([]);
});
