<?php

namespace App\Application\Mutations;

/**
 * Idempotency hash over the client's original mutation (spec 04: same key + changed payload is
 * 409). Object keys are sorted recursively so key order never matters; list order and every
 * scalar (including the original occurred_at string) are hashed exactly as sent.
 */
final class PayloadHash
{
    /** @param array<string, mixed> $mutation */
    public static function of(array $mutation): string
    {
        return hash('sha256', json_encode(self::canonical($mutation), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION));
    }

    private static function canonical(mixed $value): mixed
    {
        if (! is_array($value)) {
            return $value;
        }
        if (array_is_list($value)) {
            return array_map(self::canonical(...), $value);
        }
        ksort($value, SORT_STRING);

        return (object) array_map(self::canonical(...), $value);
    }
}
