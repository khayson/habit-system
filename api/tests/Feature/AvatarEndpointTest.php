<?php

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\Support\Images;

uses(RefreshDatabase::class);

/*
 * A20: PUT / DELETE / GET /me/avatar on real PostgreSQL and a fake private disk. Every image is
 * built in code (Tests\Support\Images).
 */

beforeEach(function () {
    $this->freezeClock('2026-05-28T17:22:00Z');
    Storage::fake('local');
    RateLimiter::clear('avatar-upload');
    $this->alice = $this->registerUser('Alice');
    $this->bob = $this->registerUser('Bob');
});

function putAvatar(object $test, string $token, ?string $bytes, ?string $key = null, string $name = 'photo.jpg'): TestResponse
{
    app('auth')->forgetGuards();
    $test->flushHeaders();
    $headers = $key === null ? [] : ['Idempotency-Key' => $key];
    $data = $bytes === null ? [] : ['photo' => UploadedFile::fake()->createWithContent($name, $bytes)];

    return $test->withToken($token)->withHeaders([...$headers, 'Accept' => 'application/json'])->put('/api/v1/me/avatar', $data);
}

function getAvatar(object $test, string $token, string $size, array $headers = []): TestResponse
{
    app('auth')->forgetGuards();
    $test->flushHeaders();

    return $test->withToken($token)->withHeaders($headers)->get("/api/v1/me/avatar/{$size}");
}

function avatarRow(string $userId): object
{
    return DB::table('users')->where('id', $userId)->first(['avatar_key', 'avatar_sha256', 'avatar_version', 'version']);
}

function avatarObjects(string $userId): array
{
    return Storage::disk('local')->allFiles("avatars/{$userId}");
}

it('stores a photo, bumps avatar_version and version, journals the user, and serves three WebP sizes', function () {
    $response = putAvatar($this, $this->alice['token'], Images::jpeg(400, 300), (string) Str::uuid7());

    $response->assertOk()->assertExactJson(['data' => ['avatar_version' => 1, 'version' => 2], 'meta' => $response->json('meta')]);
    $row = avatarRow($this->alice['id']);
    expect([(int) $row->avatar_version, (int) $row->version])->toBe([1, 2])
        ->and(avatarObjects($this->alice['id']))->toHaveCount(3);
    $change = collect($this->sync($this->alice['token'])->json('data.changes'))->last(fn ($c) => $c['entity'] === 'user');
    expect([$change['version'], $change['payload']['avatar_version'], $change['payload']['has_avatar']])->toBe([2, 1, true]);

    foreach (['sm' => 96, 'md' => 160, 'lg' => 320] as $size => $px) {
        $image = getAvatar($this, $this->alice['token'], $size)->assertOk();
        expect($image->headers->get('Content-Type'))->toBe('image/webp')
            ->and($image->headers->get('Cache-Control'))->toContain('private')
            ->and($image->headers->get('X-Content-Type-Options'))->toBe('nosniff')
            ->and($image->headers->get('ETag'))->toBe('"'.$row->avatar_sha256.'"')
            ->and(array_slice(getimagesizefromstring($image->getContent()), 0, 2))->toBe([$px, $px]);
    }
    expect($row->avatar_sha256)->toBe(hash('sha256', getAvatar($this, $this->alice['token'], 'lg')->getContent()));
});

it('answers If-None-Match with 304 and an unknown size or no photo with 404', function () {
    putAvatar($this, $this->alice['token'], Images::jpeg(100, 100), (string) Str::uuid7())->assertOk();
    $etag = getAvatar($this, $this->alice['token'], 'md')->headers->get('ETag');

    $notModified = getAvatar($this, $this->alice['token'], 'md', ['If-None-Match' => $etag]);
    expect($notModified->status())->toBe(304)->and($notModified->getContent())->toBe('');
    getAvatar($this, $this->alice['token'], 'md', ['If-None-Match' => '"other"'])->assertOk();

    getAvatar($this, $this->alice['token'], 'xl')->assertNotFound()->assertJsonPath('error.code', 'not_found');
    getAvatar($this, $this->bob['token'], 'md')->assertNotFound()->assertJsonPath('error.code', 'not_found');
});

it('never gives one owner another owner\'s bytes', function () {
    putAvatar($this, $this->alice['token'], Images::jpeg(100, 100), (string) Str::uuid7())->assertOk();
    $aliceBytes = getAvatar($this, $this->alice['token'], 'lg')->getContent();

    getAvatar($this, $this->bob['token'], 'lg')->assertNotFound();
    putAvatar($this, $this->bob['token'], Images::png(120, 90), (string) Str::uuid7())->assertOk();
    expect(getAvatar($this, $this->bob['token'], 'lg')->getContent())->not->toBe($aliceBytes);

    // A row pointing into another owner's prefix is refused, not followed.
    $alice = avatarRow($this->alice['id']);
    DB::table('users')->where('id', $this->bob['id'])->update(['avatar_key' => $alice->avatar_key, 'avatar_sha256' => $alice->avatar_sha256]);
    getAvatar($this, $this->bob['token'], 'lg')->assertNotFound();
});

it('replaces: the old objects are deleted after the new ones are committed', function () {
    putAvatar($this, $this->alice['token'], Images::jpeg(100, 100), (string) Str::uuid7())->assertOk();
    $first = avatarObjects($this->alice['id']);

    putAvatar($this, $this->alice['token'], Images::jpeg(200, 100), (string) Str::uuid7())->assertOk()->assertJsonPath('data.avatar_version', 2);

    $now = avatarObjects($this->alice['id']);
    expect($now)->toHaveCount(3)->and(array_intersect($now, $first))->toBe([]);
});

it('deletes the photo: columns cleared, versions bumped, journaled, objects removed; again changes nothing', function () {
    putAvatar($this, $this->alice['token'], Images::jpeg(100, 100), (string) Str::uuid7())->assertOk();

    app('auth')->forgetGuards();
    $this->withToken($this->alice['token'])->deleteJson('/api/v1/me/avatar')->assertOk()->assertJsonPath('data', ['avatar_version' => 2, 'version' => 3]);

    $row = avatarRow($this->alice['id']);
    expect([$row->avatar_key, $row->avatar_sha256])->toBe([null, null])
        ->and(avatarObjects($this->alice['id']))->toBe([]);
    $change = collect($this->sync($this->alice['token'])->json('data.changes'))->last(fn ($c) => $c['entity'] === 'user');
    expect([$change['version'], $change['payload']['avatar_version'], $change['payload']['has_avatar']])->toBe([3, 2, false]);
    getAvatar($this, $this->alice['token'], 'sm')->assertNotFound();

    app('auth')->forgetGuards();
    $this->withToken($this->alice['token'])->deleteJson('/api/v1/me/avatar')->assertOk()->assertJsonPath('data', ['avatar_version' => 2, 'version' => 3]);
});

it('replays a repeated Idempotency-Key without decoding again; other bytes on the same key are 409', function () {
    $key = (string) Str::uuid7();
    $bytes = Images::jpeg(100, 100);
    putAvatar($this, $this->alice['token'], $bytes, $key)->assertOk();
    $objects = avatarObjects($this->alice['id']);

    putAvatar($this, $this->alice['token'], $bytes, $key)->assertOk()->assertJsonPath('data', ['avatar_version' => 1, 'version' => 2]);
    expect(avatarObjects($this->alice['id']))->toBe($objects, 'no second set written')
        ->and((int) avatarRow($this->alice['id'])->avatar_version)->toBe(1);

    putAvatar($this, $this->alice['token'], Images::jpeg(120, 100), $key)->assertStatus(409)->assertJsonPath('error.code', 'idempotency_mismatch');
    // The key belongs to the user who sent it: another user may use the same value.
    putAvatar($this, $this->bob['token'], $bytes, $key)->assertOk()->assertJsonPath('data.avatar_version', 1);
});

it('requires an Idempotency-Key and a photo', function () {
    putAvatar($this, $this->alice['token'], Images::jpeg(50, 50))->assertStatus(422)->assertJsonPath('error.fields.idempotency_key.0', 'An Idempotency-Key (a UUID) is required.');
    putAvatar($this, $this->alice['token'], Images::jpeg(50, 50), 'not-a-uuid')->assertStatus(422);
    putAvatar($this, $this->alice['token'], null, (string) Str::uuid7())->assertStatus(422)->assertJsonPath('error.fields.photo.0', 'Choose a photo.');
});

it('refuses hostile and oversized uploads with the error envelope, storing nothing', function (Closure $build, int $status, ?string $field) {
    $response = putAvatar($this, $this->alice['token'], $build(), (string) Str::uuid7());

    $response->assertStatus($status)->assertJsonPath('error.code', $status === 413 ? 'payload_too_large' : 'validation_failed');
    if ($field !== null) {
        expect($response->json("error.fields.{$field}"))->not->toBeEmpty();
    }
    expect(avatarObjects($this->alice['id']))->toBe([])
        ->and((int) avatarRow($this->alice['id'])->avatar_version)->toBe(0);
})->with([
    'over 5 MB' => [fn () => Images::withTrailer(Images::jpeg(50, 50), str_repeat("\0", 5 * 1024 * 1024)), 413, null],
    'header claims 60000 x 60000' => [fn () => Images::pngHeaderClaiming(60000, 60000), 422, 'photo'],
    'php text named .jpg' => [fn () => '<?php echo 1;', 422, 'photo'],
]);

it('stores a polyglot only as re-encoded squares, without the appended bytes', function () {
    $input = Images::withTrailer(Images::jpeg(200, 200), "PK\x03\x04".str_repeat("\0", 26).'x.php<?php echo 1; ?>');

    putAvatar($this, $this->alice['token'], $input, (string) Str::uuid7())->assertOk();

    foreach (avatarObjects($this->alice['id']) as $key) {
        $stored = Storage::disk('local')->get($key);
        expect($stored)->not->toBe($input)->not->toContain("PK\x03\x04")->not->toContain('<?php');
    }
});

it('strips EXIF and GPS before storing', function () {
    putAvatar($this, $this->alice['token'], Images::withMetadata(Images::jpeg(300, 200), 6, true), (string) Str::uuid7())->assertOk();

    foreach (avatarObjects($this->alice['id']) as $key) {
        expect(Storage::disk('local')->get($key))->not->toContain('Exif')->not->toContain('GPS')->not->toContain('xmpmeta');
    }
});

it('lets ten uploads an hour through and answers the eleventh with 429 and Retry-After', function () {
    for ($i = 1; $i <= 10; $i++) {
        putAvatar($this, $this->alice['token'], Images::jpeg(20 + $i, 20), (string) Str::uuid7())->assertOk();
    }

    $limited = putAvatar($this, $this->alice['token'], Images::jpeg(40, 40), (string) Str::uuid7());

    $limited->assertStatus(429)->assertJsonPath('error.code', 'rate_limited');
    expect((int) $limited->headers->get('Retry-After'))->toBeGreaterThan(0);
    // Per user: another user is not limited.
    putAvatar($this, $this->bob['token'], Images::jpeg(40, 40), (string) Str::uuid7())->assertOk();
});
