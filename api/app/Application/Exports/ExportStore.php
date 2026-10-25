<?php

namespace App\Application\Exports;

use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use InvalidArgumentException;
use Throwable;

/**
 * A48: export objects on a private disk (local in dev: storage/app/private, never linked or
 * served directly), one per job: exports/{user_id}/{uuid}.{zip|csv}. Every read and delete refuses
 * a key outside exports/{caller's id}/, as AvatarStore does. Encryption at rest is the storage
 * service's (production object store with server-side encryption on).
 */
final class ExportStore
{
    private const string UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';

    private function disk(): Filesystem
    {
        return Storage::disk(config()->string('api.export_disk'));
    }

    /** Writes the bytes under a new key and returns it; a failed write leaves nothing behind. */
    public function put(string $userId, string $extension, string $bytes): string
    {
        if (! in_array($extension, ['zip', 'csv'], true)) {
            throw new InvalidArgumentException("Unknown export extension {$extension}.");
        }
        $key = 'exports/'.strtolower($userId).'/'.Str::uuid7().'.'.$extension;
        try {
            if (! $this->disk()->put($key, $bytes)) {
                throw new \RuntimeException("Could not write {$key}.");
            }
        } catch (Throwable $e) {
            $this->quietDelete($key);
            throw $e;
        }

        return $key;
    }

    /** A readable stream of the object, or null (missing, or not the caller's). */
    public function stream(string $userId, string $key): mixed
    {
        if (! $this->owns($userId, $key) || ! $this->disk()->exists($key)) {
            return null;
        }

        return $this->disk()->readStream($key);
    }

    /** Deletes one object. A failure is logged and never thrown. */
    public function delete(string $userId, string $key): void
    {
        if (! $this->owns($userId, $key)) {
            Log::warning('export delete refused: key outside the owner prefix');

            return;
        }
        $this->quietDelete($key);
    }

    /** Removes every export object of $userId and nothing of anyone else (A49 purge). */
    public function deleteAllFor(string $userId): void
    {
        $userId = strtolower($userId);
        if (! preg_match('/^'.self::UUID.'$/', $userId)) {
            throw new InvalidArgumentException('A user id is required.');
        }
        $this->disk()->deleteDirectory("exports/{$userId}");
    }

    /** True when $key is an export object under exports/{$userId}/. */
    public function owns(string $userId, string $key): bool
    {
        $prefix = 'exports/'.preg_quote(strtolower($userId), '#').'/';

        return preg_match('#^'.$prefix.self::UUID.'\.(zip|csv)$#', $key) === 1;
    }

    private function quietDelete(string $key): void
    {
        try {
            $this->disk()->delete($key);
        } catch (Throwable) {
            Log::warning('export delete failed');
        }
    }
}
