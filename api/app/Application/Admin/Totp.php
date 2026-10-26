<?php

namespace App\Application\Admin;

/**
 * A58: time-based one-time codes (RFC 6238 over RFC 4226): HMAC-SHA1, 30-second steps, six
 * digits, as authenticator apps make them. Pure: the time is passed in.
 */
final class Totp
{
    public const int STEP = 30;

    private const string ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

    /** A fresh 160-bit secret, base32 without padding. */
    public static function newSecret(): string
    {
        return self::base32Encode(random_bytes(20));
    }

    public static function code(string $secret, int $step): string
    {
        $key = self::base32Decode($secret);
        $hash = hash_hmac('sha1', pack('J', $step), $key, true);
        $offset = ord($hash[19]) & 0x0F;
        $value = ((ord($hash[$offset]) & 0x7F) << 24)
            | (ord($hash[$offset + 1]) << 16)
            | (ord($hash[$offset + 2]) << 8)
            | ord($hash[$offset + 3]);

        return str_pad((string) ($value % 1_000_000), 6, '0', STR_PAD_LEFT);
    }

    /**
     * The step [$code] matches at [$unixTime], allowing one step of drift either way; null when
     * none does. Compared in constant time.
     */
    public static function matchStep(string $secret, string $code, int $unixTime): ?int
    {
        if (! preg_match('/^\d{6}$/', $code)) {
            return null;
        }
        $now = intdiv($unixTime, self::STEP);
        $found = null;
        foreach ([$now - 1, $now, $now + 1] as $step) {
            if (hash_equals(self::code($secret, $step), $code)) {
                $found = $step;
            }
        }

        return $found;
    }

    public static function uri(string $secret, string $account, string $issuer = 'Habit System admin'): string
    {
        return 'otpauth://totp/'.rawurlencode($issuer.':'.$account)
            .'?secret='.$secret.'&issuer='.rawurlencode($issuer).'&algorithm=SHA1&digits=6&period='.self::STEP;
    }

    private static function base32Encode(string $bytes): string
    {
        $bits = '';
        foreach (str_split($bytes) as $byte) {
            $bits .= str_pad(decbin(ord($byte)), 8, '0', STR_PAD_LEFT);
        }
        $out = '';
        foreach (str_split($bits, 5) as $chunk) {
            $out .= self::ALPHABET[(int) bindec(str_pad($chunk, 5, '0')) & 31];
        }

        return $out;
    }

    private static function base32Decode(string $text): string
    {
        $bits = '';
        foreach (str_split(strtoupper(rtrim($text, '='))) as $char) {
            $index = strpos(self::ALPHABET, $char);
            if ($index === false) {
                continue;
            }
            $bits .= str_pad(decbin($index), 5, '0', STR_PAD_LEFT);
        }
        $out = '';
        foreach (str_split($bits, 8) as $byte) {
            if (strlen($byte) === 8) {
                $out .= chr((int) bindec($byte));
            }
        }

        return $out;
    }
}
