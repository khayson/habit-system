<?php

namespace App\Application\Avatars;

use App\Application\Habits\HabitRepository;
use App\Application\Journal\ChangeJournal;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Avatar\AvatarPipeline;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use stdClass;
use Throwable;

/**
 * A20: photo upload, removal and read. A photo is binary, so it is not a journal mutation, but
 * every change bumps users.avatar_version and users.version and journals the user entity in the
 * same transaction (invariant 6).
 *
 * PUT order: replay check → pipeline → write the new objects → one transaction (lock the user,
 * point at the new objects, bump both versions, journal, store the receipt) → delete the old
 * objects after commit. A failed transaction deletes the new objects; a failed delete is logged.
 *
 * Replays reuse mutation_receipts with operation avatar.put and the sha256 of the uploaded
 * bytes as the payload hash: the same key from the same user returns the first result without
 * decoding again; the same key with other bytes (or a key already used by a sync mutation) is
 * 409 idempotency_mismatch.
 */
final readonly class AvatarService
{
    public const string OPERATION = 'avatar.put';

    public function __construct(
        private AvatarStore $store,
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    /** @return array{avatar_version: int, version: int} */
    public function put(string $userId, string $idempotencyKey, string $bytes, AvatarPipeline $pipeline): array
    {
        $hash = hash('sha256', $bytes);
        $stored = $this->replay($userId, $idempotencyKey, $hash);
        if ($stored !== null) {
            return $stored;
        }

        $images = $pipeline->process($bytes);
        $newKey = $this->store->put($userId, $images);
        $old = null;
        try {
            $result = DB::transaction(function () use ($userId, $idempotencyKey, $hash, $images, $newKey, &$old): array {
                $this->journal->lockUser($userId);
                // Another request with the same key may have finished while this one decoded.
                $stored = $this->replay($userId, $idempotencyKey, $hash);
                if ($stored !== null) {
                    $old = $newKey;

                    return $stored;
                }
                $user = $this->user($userId);
                $old = $user->avatar_key;
                $result = $this->write($user, [
                    'avatar_key' => $newKey,
                    'avatar_sha256' => $images->sha256,
                ]);
                DB::table('mutation_receipts')->insert([
                    'user_id' => $userId,
                    'mutation_id' => $idempotencyKey,
                    'device_id' => null,
                    'operation' => self::OPERATION,
                    'payload_hash' => $hash,
                    'result' => json_encode($result, JSON_THROW_ON_ERROR),
                    'committed_at' => UtcTime::format($this->clock->now()),
                ]);

                return $result;
            });
        } catch (Throwable $e) {
            $this->store->deleteSet($userId, $newKey);
            throw $e;
        }
        if (is_string($old) && $old !== '') {
            $this->store->deleteSet($userId, $old);
        }

        return $result;
    }

    /**
     * Removes the photo. Without one, answers the current versions and changes nothing.
     *
     * @return array{avatar_version: int, version: int}
     */
    public function delete(string $userId): array
    {
        $old = null;
        $result = DB::transaction(function () use ($userId, &$old): array {
            $this->journal->lockUser($userId);
            $user = $this->user($userId);
            if ($user->avatar_key === null) {
                return ['avatar_version' => (int) $user->avatar_version, 'version' => (int) $user->version];
            }
            $old = $user->avatar_key;

            return $this->write($user, ['avatar_key' => null, 'avatar_sha256' => null]);
        });
        if (is_string($old)) {
            $this->store->deleteSet($userId, $old);
        }

        return $result;
    }

    /** @return array{bytes: string, etag: string, content_type: string}|null */
    public function read(string $userId, string $size): ?array
    {
        $user = $this->user($userId);
        if (! is_string($user->avatar_key) || ! is_string($user->avatar_sha256)) {
            return null;
        }
        $bytes = $this->store->read($userId, $user->avatar_key, $size);

        return $bytes === null ? null : [
            'bytes' => $bytes,
            'etag' => $user->avatar_sha256,
            'content_type' => AvatarStore::contentType($user->avatar_key),
        ];
    }

    /**
     * @param  array<string, string|null>  $avatar
     * @return array{avatar_version: int, version: int}
     */
    private function write(stdClass $user, array $avatar): array
    {
        $avatarVersion = (int) $user->avatar_version + 1;
        $version = (int) $user->version + 1;
        DB::table('users')->where('id', $user->id)->update([
            ...$avatar,
            'avatar_version' => $avatarVersion,
            'version' => $version,
            'updated_at' => UtcTime::format($this->clock->now()),
        ]);
        $row = DB::table('users')->where('id', $user->id)->first() ?? (object) [];
        $this->journal->append((string) $user->id, 'user', (string) $user->id, 'upsert', $version, $this->presenter->user($row));

        return ['avatar_version' => $avatarVersion, 'version' => $version];
    }

    /** @return array{avatar_version: int, version: int}|null */
    private function replay(string $userId, string $key, string $hash): ?array
    {
        $receipt = DB::table('mutation_receipts')->where('user_id', $userId)->where('mutation_id', $key)->first();
        if ($receipt === null) {
            return null;
        }
        if ($receipt->operation !== self::OPERATION || ! hash_equals((string) $receipt->payload_hash, $hash)) {
            throw ApiException::idempotencyMismatch();
        }
        $result = HabitRepository::json($receipt->result);

        return ['avatar_version' => (int) $result['avatar_version'], 'version' => (int) $result['version']];
    }

    private function user(string $userId): stdClass
    {
        return DB::table('users')->where('id', $userId)->first() ?? throw new ApiException(404, 'not_found', 'Not found.');
    }
}
