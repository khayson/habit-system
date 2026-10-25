<?php

use App\Application\Exports\ExportBuilder;
use App\Application\Habits\HabitIconBackfill;
use App\Domain\Habit\HabitIcons;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A53: a habit's chosen icon (contract-fixtures/habit/icons.json). Presentation only: a key of
 * the right shape or null, never a definition version.
 */

/** @return array<string, mixed> */
function iconFixture(): array
{
    return contractFixture('habit/icons.json');
}

/** @param array<string, mixed> $payload */
function habitUpdate(string $habitId, int $baseVersion, array $payload): array
{
    return [
        'mutation_id' => (string) Str::uuid7(),
        'entity' => 'habit',
        'entity_id' => $habitId,
        'operation' => 'habit.update',
        'base_version' => $baseVersion,
        'occurred_at' => '2026-05-28T17:10:00Z',
        'captured_timezone' => 'America/Los_Angeles',
        'payload' => [
            'name' => 'Morning plan', 'target_value' => 1, 'unit' => null, 'category' => 'productivity',
            'frequency_type' => 'daily', 'frequency_config' => [], ...$payload,
        ],
    ];
}

/** The habit as the journal last published it. */
function journaledHabit(string $userId, string $habitId): array
{
    $row = DB::table('server_changes')->where('user_id', $userId)->where('entity_type', 'habit')
        ->where('entity_id', $habitId)->orderByDesc('seq')->first();

    return json_decode((string) $row->payload, true);
}

beforeEach(function () {
    $this->freezeClock(iconFixture()['now']);
    $this->maya = $this->registerUser('Maya');
});

it('keeps the server keyword table equal to the fixture, and suggests as the examples say', function () {
    $fixture = iconFixture();
    expect(HabitIcons::KEY_PATTERN)->toBe('/'.$fixture['key_pattern'].'/')
        ->and(HabitIcons::MAX_LENGTH)->toBe($fixture['max_length'])
        ->and(HabitIcons::KEYWORDS)->toBe(array_map(fn ($k) => [$k['prefixes'], $k['icon']], $fixture['keywords']));
    foreach ($fixture['suggest_examples'] as $example) {
        expect(HabitIcons::suggest($example['name']))->toBe($example['icon'], $example['name']);
    }
});

it('accepts every valid key shape on create', function (string $key) {
    $id = (string) Str::uuid7();
    $ack = $this->sync($this->maya['token'], [M::habitCreate($id, overrides: ['icon' => $key])])->json('data.acks.0');
    expect($ack['status'])->toBe('accepted', json_encode($ack))
        ->and(journaledHabit($this->maya['id'], $id)['icon'])->toBe($key);
})->with(fn () => iconFixture()['valid_keys']);

it('rejects every invalid key on create and on update with validation_failed on icon', function (mixed $key) {
    $expect = iconFixture()['mutations']['invalid']['expect'];
    $id = (string) Str::uuid7();
    $ack = $this->sync($this->maya['token'], [M::habitCreate($id, overrides: ['icon' => $key])])->json('data.acks.0');
    expect($ack['status'])->toBe($expect['status'])
        ->and($ack['error']['code'])->toBe($expect['error_code'])
        ->and($ack['error']['fields'])->toHaveKey($expect['field']);

    $this->sync($this->maya['token'], [M::habitCreate($id)])->assertOk();
    $ack = $this->sync($this->maya['token'], [habitUpdate($id, 1, ['icon' => $key])])->json('data.acks.0');
    expect($ack['status'])->toBe($expect['status'])
        ->and($ack['error']['fields'])->toHaveKey($expect['field'])
        ->and(DB::table('habits')->where('id', $id)->value('icon'))->toBeNull();
})->with(fn () => array_map(fn ($k) => [$k], iconFixture()['invalid_keys']));

it('creates with and without an icon', function () {
    $m = iconFixture()['mutations'];
    $with = (string) Str::uuid7();
    $without = (string) Str::uuid7();
    $acks = $this->sync($this->maya['token'], [
        M::habitCreate($with, overrides: ['icon' => $m['create_with_icon']['payload_icon']]),
        M::habitCreate($without),
    ])->json('data.acks');
    expect($acks[0]['version'])->toBe($m['create_with_icon']['expect']['version'])
        ->and(journaledHabit($this->maya['id'], $with)['icon'])->toBe($m['create_with_icon']['expect']['icon'])
        ->and(journaledHabit($this->maya['id'], $without))->toHaveKey('icon')
        ->and(journaledHabit($this->maya['id'], $without)['icon'])->toBe($m['create_without_icon']['expect']['icon']);
});

it('replays the habit.update icon cases', function (string $case) {
    $c = iconFixture()['mutations'][$case];
    $id = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($id, overrides: ['icon' => $c['from']])])->assertOk();
    $journal = DB::table('server_changes')->where('user_id', $this->maya['id'])->count();

    $payload = [];
    if (array_key_exists('payload_icon', $c)) {
        $payload['icon'] = $c['payload_icon'];
    }
    if (isset($c['payload_name'])) {
        $payload['name'] = $c['payload_name'];
    }
    $ack = $this->sync($this->maya['token'], [habitUpdate($id, 1, $payload)])->json('data.acks.0');

    expect($ack['status'])->toBe($c['expect']['status'], json_encode($ack))
        ->and($ack['version'])->toBe($c['expect']['version']);
    $habit = journaledHabit($this->maya['id'], $id);
    if (array_key_exists('icon', $c['expect'])) {
        expect($habit['icon'])->toBe($c['expect']['icon']);
    }
    if (isset($c['expect']['definition_version'])) {
        expect($habit['definition_version'])->toBe($c['expect']['definition_version'])
            ->and($habit['definitions'])->toHaveCount($c['expect']['definitions'])
            ->and(DB::table('habit_definition_versions')->where('habit_id', $id)->count())->toBe($c['expect']['definitions']);
    }
    if (($c['expect']['journaled'] ?? true) === false) {
        expect(DB::table('server_changes')->where('user_id', $this->maya['id'])->count())->toBe($journal);
    }
})->with(['update_icon_only', 'update_icon_absent_keeps', 'update_icon_null_clears', 'update_same_icon_noop']);

it('carries the icon in bootstrap and the JSON export', function () {
    $id = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($id, overrides: ['icon' => 'book-open-01'])])->assertOk();

    $page = $this->bootstrapPage($this->maya['token'], null, 100)->json('data');
    expect(collect($page['habits'])->firstWhere('id', $id)['icon'])->toBe('book-open-01');

    $built = app(ExportBuilder::class)->build($this->maya['id'], 'json');
    $path = tempnam(sys_get_temp_dir(), 'zip');
    file_put_contents($path, $built['bytes']);
    $zip = new ZipArchive;
    $zip->open($path);
    $doc = json_decode((string) $zip->getFromName('export.json'), true);
    $zip->close();
    @unlink($path);
    expect(collect($doc['habits'])->firstWhere('id', $id)['icon'])->toBe('book-open-01');
});

it('backfills existing habits from their names and never overwrites a chosen icon', function () {
    $ids = [];
    foreach (['Reading', 'Drink water', 'Pilates', 'Morning run', 'Gym session'] as $name) {
        $ids[$name] = (string) Str::uuid7();
        $this->sync($this->maya['token'], [M::habitCreate($ids[$name], overrides: ['name' => $name])])->assertOk();
    }
    DB::table('habits')->update(['icon' => null]);
    DB::table('habits')->where('id', $ids['Gym session'])->update(['icon' => 'yoga-01']); // chosen

    app(HabitIconBackfill::class)->run();

    $icons = DB::table('habits')->pluck('icon', 'id');
    expect($icons[$ids['Reading']])->toBe('book-open-01')
        ->and($icons[$ids['Drink water']])->toBe('glass-water')
        ->and($icons[$ids['Pilates']])->toBeNull()
        ->and($icons[$ids['Morning run']])->toBe('workout-run')
        ->and($icons[$ids['Gym session']])->toBe('yoga-01');
    // Synced devices receive it: a new version, journaled (invariant 6).
    $reading = journaledHabit($this->maya['id'], $ids['Reading']);
    expect($reading['icon'])->toBe('book-open-01')
        ->and($reading['version'])->toBe(2)
        ->and(DB::table('habits')->where('id', $ids['Pilates'])->value('version'))->toBe(1);
});

it('lets the database refuse a malformed icon', function () {
    $id = (string) Str::uuid7();
    $this->sync($this->maya['token'], [M::habitCreate($id)])->assertOk();
    expect(fn () => DB::transaction(fn () => DB::table('habits')->where('id', $id)->update(['icon' => 'Book 02'])))
        ->toThrow(QueryException::class);
});
