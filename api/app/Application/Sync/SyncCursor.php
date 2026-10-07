<?php

namespace App\Application\Sync;

/**
 * Opaque cursors bound to one user (spec 07). The payload is signed with the app key so a client
 * can neither forge a position nor reuse another user's cursor. Same format for /sync positions
 * and /sync/bootstrap pages; `t` tells them apart.
 */
final class SyncCursor
{
    /** @param array<string, mixed> $state */
    public static function encode(string $userId, string $type, array $state): string
    {
        $payload = self::base64url(json_encode(['v' => 1, 't' => $type, 'u' => $userId, ...$state], JSON_THROW_ON_ERROR));

        return $payload.'.'.self::base64url(hash_hmac('sha256', $payload, self::key(), true));
    }

    /**
     * @return array<string, mixed>|null null when malformed, tampered, of another type, or another user's
     */
    public static function decode(string $cursor, string $userId, string $type): ?array
    {
        $parts = explode('.', $cursor);
        if (count($parts) !== 2) {
            return null;
        }
        [$payload, $signature] = $parts;
        if (! hash_equals(self::base64url(hash_hmac('sha256', $payload, self::key(), true)), $signature)) {
            return null;
        }
        $decoded = base64_decode(strtr($payload, '-_', '+/'), true);
        $data = $decoded === false ? null : json_decode($decoded, true);

        return is_array($data) && ($data['v'] ?? null) === 1 && ($data['t'] ?? null) === $type && ($data['u'] ?? null) === $userId
            ? $data
            : null;
    }

    public static function forSeq(string $userId, int $seq): string
    {
        return self::encode($userId, 's', ['s' => $seq]);
    }

    /** The seq a /sync cursor points at, or null when invalid for this user. */
    public static function seqOf(string $cursor, string $userId): ?int
    {
        $data = self::decode($cursor, $userId, 's');

        return is_int($data['s'] ?? null) && $data['s'] >= 0 ? $data['s'] : null;
    }

    private static function base64url(string $bytes): string
    {
        return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
    }

    private static function key(): string
    {
        return 'habit-sync-cursor|'.(string) config('app.key');
    }
}
