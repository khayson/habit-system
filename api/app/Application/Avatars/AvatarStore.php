<?php

namespace App\Application\Avatars;

use App\Domain\Avatar\AvatarImages;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

/**
 * A20: avatar objects on a private disk (local in dev: storage/app/private, never linked or
 * served directly). One photo is three objects:
 *   avatars/{user_id}/{uuid}-{sm|md|lg}.{webp|jpg}
 * ASSUMPTION(A3b-avatar-paths): A20 shows one key; three sizes need the suffix. users.avatar_key
 * holds the lg key. Every read and delete refuses a key outside avatars/{caller's id}/.
 */
final class AvatarStore
{
    public const array SIZES = ['sm', 'md', 'lg'];

    private const string UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

    private function disk(): Filesystem
    {
        return Storage::disk(config()->string('api.avatar_disk'));
    }

    /** Writes the three sizes under a new id and returns the lg key. Partial writes are removed. */
    public function put(string $userId, AvatarImages $images): string
    {
        $base = 'avatars/'.strtolower($userId).'/'.Str::uuid7();
        $written = [];
        try {
            foreach (self::SIZES as $size) {
                $key = "{$base}-{$size}.{$images->extension}";
                if (! $this->disk()->put($key, $images->sizes[$size])) {
                    throw new \RuntimeException("Could not write {$key}.");
                }
                $written[] = $key;
            }
        } catch (Throwable $e) {
            foreach ($written as $key) {
                $this->quietDelete($key);
            }
            throw $e;
        }

        return "{$base}-lg.{$images->extension}";
    }

    /** The bytes of $size for the photo whose lg key is $lgKey, or null (missing, or not the caller's). */
    public function read(string $userId, string $lgKey, string $size): ?string
    {
        if (! in_array($size, self::SIZES, true) || ! $this->owns($userId, $lgKey)) {
            return null;
        }
        $key = self::sizeKey($lgKey, $size);

        return $this->disk()->exists($key) ? $this->disk()->get($key) : null;
    }

    /** Deletes the three objects of one photo. A failure is logged and never thrown. */
    public function deleteSet(string $userId, string $lgKey): void
    {
        if (! $this->owns($userId, $lgKey)) {
            Log::warning('avatar delete refused: key outside the owner prefix');

            return;
        }
        foreach (self::SIZES as $size) {
            $this->quietDelete(self::sizeKey($lgKey, $size));
        }
    }

    /** Removes every avatar object of $userId and nothing of anyone else (account purge, Phase 6). */
    public function deleteAllFor(string $userId): void
    {
        $userId = strtolower($userId);
        if (! preg_match('/^'.self::UUID.'$/', $userId)) {
            throw new \InvalidArgumentException('A user id is required.');
        }
        $this->disk()->deleteDirectory("avatars/{$userId}");
    }

    /** True when $lgKey is an lg object key under avatars/{$userId}/. */
    public function owns(string $userId, string $lgKey): bool
    {
        $prefix = 'avatars/'.preg_quote(strtolower($userId), '#').'/';

        return preg_match('#^'.$prefix.self::UUID.'-lg\.(webp|jpg)$#', $lgKey) === 1;
    }

    public static function contentType(string $lgKey): string
    {
        return str_ends_with($lgKey, '.webp') ? 'image/webp' : 'image/jpeg';
    }

    private static function sizeKey(string $lgKey, string $size): string
    {
        return (string) preg_replace('/-lg\.(webp|jpg)$/', "-{$size}.$1", $lgKey);
    }

    private function quietDelete(string $key): void
    {
        try {
            if (! $this->disk()->delete($key) && $this->disk()->exists($key)) {
                Log::warning('avatar object delete failed', ['key' => $key]);
            }
        } catch (Throwable $e) {
            Log::warning('avatar object delete failed', ['key' => $key, 'error' => $e->getMessage()]);
        }
    }
}
