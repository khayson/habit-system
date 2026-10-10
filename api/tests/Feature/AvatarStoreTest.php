<?php

use App\Application\Avatars\AvatarStore;
use App\Domain\Avatar\AvatarImages;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/*
 * A20: AvatarStore on a fake private disk. Keys stay under avatars/{owner}/.
 */

beforeEach(function () {
    Storage::fake('local');
    $this->store = new AvatarStore;
    $this->alice = (string) Str::uuid7();
    $this->bob = (string) Str::uuid7();
});

function images(string $tag): AvatarImages
{
    return new AvatarImages(['sm' => "{$tag}-sm", 'md' => "{$tag}-md", 'lg' => "{$tag}-lg"], hash('sha256', "{$tag}-lg"), 'webp', 'image/webp');
}

it('writes three sizes under the owner prefix and reads each back', function () {
    $key = $this->store->put($this->alice, images('a'));

    expect($key)->toMatch('#^avatars/'.$this->alice.'/[0-9a-f-]{36}-lg\.webp$#');
    expect(Storage::disk('local')->allFiles("avatars/{$this->alice}"))->toHaveCount(3);
    foreach (['sm', 'md', 'lg'] as $size) {
        expect($this->store->read($this->alice, $key, $size))->toBe("a-{$size}");
    }
    expect($this->store->read($this->alice, $key, 'xl'))->toBeNull();
});

it('refuses a key outside the caller\'s prefix, for reads and deletes', function () {
    $aliceKey = $this->store->put($this->alice, images('a'));

    expect($this->store->read($this->bob, $aliceKey, 'lg'))->toBeNull()
        ->and($this->store->owns($this->bob, $aliceKey))->toBeFalse()
        ->and($this->store->owns($this->alice, "avatars/{$this->alice}/../{$this->bob}/x-lg.webp"))->toBeFalse()
        ->and($this->store->owns($this->alice, "avatars/{$this->alice}/".Str::uuid7().'-lg.php'))->toBeFalse();

    $this->store->deleteSet($this->bob, $aliceKey);
    expect(Storage::disk('local')->allFiles("avatars/{$this->alice}"))->toHaveCount(3, 'untouched');
});

it('replaces: the old set can be deleted and the new one stays', function () {
    $old = $this->store->put($this->alice, images('old'));
    $new = $this->store->put($this->alice, images('new'));

    $this->store->deleteSet($this->alice, $old);

    expect($this->store->read($this->alice, $old, 'lg'))->toBeNull()
        ->and($this->store->read($this->alice, $new, 'lg'))->toBe('new-lg')
        ->and(Storage::disk('local')->allFiles("avatars/{$this->alice}"))->toHaveCount(3);
});

it('deleteAllFor removes every object of one user and none of another', function () {
    $this->store->put($this->alice, images('a1'));
    $this->store->put($this->alice, images('a2'));
    $bobKey = $this->store->put($this->bob, images('b'));

    $this->store->deleteAllFor($this->alice);

    expect(Storage::disk('local')->allFiles("avatars/{$this->alice}"))->toBe([])
        ->and($this->store->read($this->bob, $bobKey, 'md'))->toBe('b-md');
    expect(fn () => $this->store->deleteAllFor('../'))->toThrow(InvalidArgumentException::class);
});
