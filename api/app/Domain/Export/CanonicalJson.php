<?php

namespace App\Domain\Export;

/**
 * A16 / A48: the canonical JSON a manifest is signed over. Object keys sorted at every level,
 * lists kept in order, no whitespace, UTF-8 and slashes unescaped, integers as integers.
 */
final class CanonicalJson
{
    public static function encode(mixed $value): string
    {
        return json_encode(self::sorted($value), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
    }

    private static function sorted(mixed $value): mixed
    {
        if (! is_array($value)) {
            return $value;
        }
        if (array_is_list($value)) {
            return array_map(self::sorted(...), $value);
        }
        ksort($value, SORT_STRING);

        return array_map(self::sorted(...), $value);
    }
}
