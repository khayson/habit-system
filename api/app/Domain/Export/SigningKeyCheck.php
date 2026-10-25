<?php

namespace App\Domain\Export;

/**
 * 6.1 review L3: whether the current export signing key may sign outside local and testing. The
 * published test secret (phpunit.xml, CI) would let anyone forge a "verified own export" and skip
 * the backdate limit (A16); a short secret is guessable.
 */
final class SigningKeyCheck
{
    public const string PUBLISHED_TEST_SECRET = 'test-export-signing-secret-not-for-production';

    public const int MIN_SECRET_BYTES = 32;

    public const string MISSING = 'missing';

    public const string TEST_KEY = 'test_key';

    public const string TOO_SHORT = 'too_short';

    /**
     * @param  array<string, string>  $keys  kid => secret
     * @return self::MISSING|self::TEST_KEY|self::TOO_SHORT|null null when the key may sign
     */
    public static function problem(array $keys, string $currentKid): ?string
    {
        $secret = $keys[$currentKid] ?? null;

        return match (true) {
            $secret === null => self::MISSING,
            hash_equals(self::PUBLISHED_TEST_SECRET, $secret) => self::TEST_KEY,
            strlen($secret) < self::MIN_SECRET_BYTES => self::TOO_SHORT,
            default => null,
        };
    }
}
