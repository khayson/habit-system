<?php

use App\Application\Exports\ExportBuilder;
use App\Domain\Export\ManifestCheck;
use App\Jobs\RunExportJob;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\M;

uses(RefreshDatabase::class);

/*
 * A48: POST /exports, GET /exports, GET /exports/{id} and the signed download, against
 * contract-fixtures/exports/export_job.json. The queue runs synchronously in tests.
 */

beforeEach(function () {
    Storage::fake('local');
    $this->freezeClock('2026-05-28T17:22:00Z');
    $this->maya = $this->registerUser('Maya Chen', 'maya@example.com');
    $this->habit = (string) Str::uuid7();
    $this->sync($this->maya['token'], [
        M::habitCreate($this->habit, 'quantity', '2000.000', ['name' => '=Water', 'unit' => 'mL', 'start_local_date' => '2026-05-20', 'date_mode' => 'backdate']),
        M::setValue($this->habit, '2000.000', 0, '2026-05-28T17:00:00Z'),
    ])->assertOk();
});

function exportsCall(object $test, string $method, string $token, string $path, array $body = []): TestResponse
{
    app('auth')->forgetGuards();

    return $test->withToken($token)->json($method, '/api/v1'.$path, $body);
}

function jobFixture(): array
{
    return contractFixture('exports/export_job.json');
}

/** Opens a produced zip and returns its files by name. */
function zipFiles(string $bytes): array
{
    $path = tempnam(sys_get_temp_dir(), 'zip-test-');
    file_put_contents($path, $bytes);
    $zip = new ZipArchive;
    $zip->open($path);
    $files = [];
    for ($i = 0; $i < $zip->numFiles; $i++) {
        $name = (string) $zip->getNameIndex($i);
        $files[$name] = (string) $zip->getFromIndex($i);
    }
    $zip->close();
    unlink($path);

    return $files;
}

function downloadBytes(object $test, string $token, string $url): TestResponse
{
    app('auth')->forgetGuards();

    return $test->withToken($token)->get($url);
}

it('queues a job and answers in the fixture shapes for each status', function () {
    Queue::fake();
    $queued = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->assertStatus(202)->json('data');
    assertMatchesContract(jobFixture()['jobs']['queued'], $queued);
    Queue::assertPushed(RunExportJob::class, 1);

    DB::table('export_jobs')->update(['status' => 'running']);
    assertMatchesContract(jobFixture()['jobs']['running'], exportsCall($this, 'GET', $this->maya['token'], "/exports/{$queued['id']}")->json('data'));

    DB::table('export_jobs')->update(['status' => 'failed', 'error_code' => 'export_failed']);
    assertMatchesContract(jobFixture()['jobs']['failed'], exportsCall($this, 'GET', $this->maya['token'], "/exports/{$queued['id']}")->json('data'));
});

it('builds a ready JSON export: signed manifest, the account\'s data, and no secrets', function () {
    $job = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->assertStatus(202)->json('data');
    $ready = exportsCall($this, 'GET', $this->maya['token'], "/exports/{$job['id']}")->assertOk()->json('data');
    assertMatchesContract(jobFixture()['jobs']['ready'], $ready);
    expect($ready['expires_at'])->toBe('2026-05-29T17:22:00Z');

    $response = downloadBytes($this, $this->maya['token'], $ready['download_url'])->assertOk();
    expect($response->headers->get('Cache-Control'))->toContain('no-store')->toContain('private');
    $files = zipFiles($response->streamedContent());

    expect(array_keys($files))->toEqualCanonicalizing(['export.json', 'manifest.json']);
    $manifest = json_decode($files['manifest.json'], true);
    expect(app(ExportBuilder::class)->signer()->verify($manifest))->toBe(ManifestCheck::Valid)
        ->and([$manifest['user_id'], $manifest['snapshot_seq']])->toBe([$this->maya['id'], $ready['snapshot_seq']])
        ->and($manifest['files'][0])->toBe(['name' => 'export.json', 'sha256' => hash('sha256', $files['export.json'])]);
    $export = json_decode($files['export.json'], true);
    expect($export['profile'])->toBe(['name' => 'Maya Chen', 'email' => 'maya@example.com', 'city' => null, 'country_code' => null])
        ->and(count($export['habits']))->toBe(1)
        ->and(count($export['logs']))->toBe(1)
        ->and(count($export['xp_entitlements']))->toBe(1)
        ->and(count($export['freeze_ledger']))->toBe(1);

    // Never: password hashes, tokens, device ids, diagnostics.
    $hash = (string) DB::table('users')->where('id', $this->maya['id'])->value('password');
    $tokenHash = (string) DB::table('personal_access_tokens')->value('token');
    $deviceId = (string) DB::table('personal_access_tokens')->value('device_id');
    foreach ($files as $name => $bytes) {
        foreach ([$hash, $tokenHash, $deviceId, explode('|', $this->maya['token'])[1], '"password"', '"token"', 'device_id'] as $secret) {
            expect(str_contains($bytes, $secret))->toBeFalse("{$name} contains a secret");
        }
    }
});

it('builds a CSV export with neutralised cells', function () {
    $job = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'csv'])->assertStatus(202)->json('data');
    $ready = exportsCall($this, 'GET', $this->maya['token'], "/exports/{$job['id']}")->json('data');

    $csv = downloadBytes($this, $this->maya['token'], $ready['download_url'])->assertOk()->streamedContent();

    $lines = explode("\n", trim($csv));
    expect($lines[0])->toBe('local_date,habit_id,habit_name,category,type,value,unit,target,completed,note')
        ->and($lines[1])->toBe("2026-05-28,{$this->habit},'=Water,productivity,quantity,2000.000,mL,2000.000,true,");
});

it('returns the open job instead of queueing a second one', function () {
    Queue::fake();
    $first = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->json('data.id');
    $second = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->assertStatus(202)->json('data.id');
    $csv = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'csv'])->json('data.id');

    expect($second)->toBe($first)->and($csv)->not->toBe($first)
        ->and(DB::table('export_jobs')->count())->toBe(2);
    Queue::assertPushed(RunExportJob::class, 2);
});

it('lists the five newest jobs, newest first, in the fixture shape', function () {
    Queue::fake();
    $ids = [];
    for ($i = 0; $i < 6; $i++) {
        $this->freezeClock(sprintf('2026-05-28T17:%02d:00Z', 22 + $i));
        $ids[] = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->json('data.id');
        DB::table('export_jobs')->update(['status' => 'failed', 'error_code' => 'export_failed']);
    }

    $list = exportsCall($this, 'GET', $this->maya['token'], '/exports')->assertOk()->json('data');

    expect(array_column($list, 'id'))->toBe(array_reverse(array_slice($ids, 1)));
    assertMatchesContract(jobFixture()['jobs']['failed'], $list[0]);
});

it('answers another user\'s job, or a missing one, with the same 404 on every route', function () {
    $job = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->json('data');
    $url = exportsCall($this, 'GET', $this->maya['token'], "/exports/{$job['id']}")->json('data.download_url');
    $bob = $this->registerUser('Bob');

    exportsCall($this, 'GET', $bob['token'], "/exports/{$job['id']}")->assertNotFound()->assertJsonPath('error.code', 'not_found');
    exportsCall($this, 'GET', $bob['token'], '/exports/'.Str::uuid7())->assertNotFound();
    exportsCall($this, 'GET', $bob['token'], '/exports/not-a-uuid')->assertNotFound();
    downloadBytes($this, $bob['token'], $url)->assertNotFound()->assertJsonPath('error.code', 'not_found');
    expect(exportsCall($this, 'GET', $bob['token'], '/exports')->json('data'))->toBe([]);
});

it('refuses the download without a session, with a tampered signature, and after 24 hours', function () {
    $job = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->json('data');
    $url = exportsCall($this, 'GET', $this->maya['token'], "/exports/{$job['id']}")->json('data.download_url');

    app('auth')->forgetGuards();
    $this->flushHeaders();
    $this->getJson($url)->assertUnauthorized();
    downloadBytes($this, $this->maya['token'], preg_replace('/signature=[0-9a-f]{4}/', 'signature=0000', $url))
        ->assertForbidden()->assertJsonPath('error.code', 'forbidden');

    $this->freezeClock('2026-05-29T17:22:00Z');
    downloadBytes($this, $this->maya['token'], $url)->assertStatus(410)->assertJsonPath('error.code', 'export_expired');
    expect(exportsCall($this, 'GET', $this->maya['token'], "/exports/{$job['id']}")->json('data.status'))->toBe('expired');
});

it('expires ready jobs past their 24 hours and deletes their objects', function () {
    $job = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->json('data');
    $key = (string) DB::table('export_jobs')->value('object_key');
    Storage::disk('local')->assertExists($key);

    $this->freezeClock('2026-05-29T17:21:00Z');
    Artisan::call('exports:expire');
    expect(DB::table('export_jobs')->value('status'))->toBe('ready');

    $this->freezeClock('2026-05-29T17:22:00Z');
    Artisan::call('exports:expire');
    expect(DB::table('export_jobs')->value('status'))->toBe('expired');
    Storage::disk('local')->assertMissing($key);
    assertMatchesContract(jobFixture()['jobs']['expired'], exportsCall($this, 'GET', $this->maya['token'], "/exports/{$job['id']}")->json('data'));
});

it('fails without touching history or the journal, and leaves no object', function () {
    $seq = (int) DB::table('users')->where('id', $this->maya['id'])->value('change_seq');
    $logs = DB::table('habit_logs')->get()->toJson();
    config(['api.export_signing_kid' => 'missing-kid']);

    $job = exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'json'])->assertStatus(202)->json('data');

    $row = DB::table('export_jobs')->where('id', $job['id'])->first();
    expect([$row->status, $row->error_code, $row->object_key])->toBe(['failed', 'export_failed', null])
        ->and((int) DB::table('users')->where('id', $this->maya['id'])->value('change_seq'))->toBe($seq)
        ->and(DB::table('habit_logs')->get()->toJson())->toBe($logs)
        ->and(Storage::disk('local')->allFiles('exports'))->toBe([]);
});

it('validates the format and needs a session', function () {
    exportsCall($this, 'POST', $this->maya['token'], '/exports', ['format' => 'pdf'])->assertStatus(422)->assertJsonPath('error.code', 'validation_failed');
    app('auth')->forgetGuards();
    $this->flushHeaders();
    $this->postJson('/api/v1/exports', ['format' => 'json'])->assertUnauthorized();
});
