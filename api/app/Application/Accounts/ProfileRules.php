<?php

namespace App\Application\Accounts;

use Closure;

/**
 * Validation rules for the profile fields, shared by registration and profile.update so the two
 * never drift apart.
 */
final class ProfileRules
{
    public const int CITY_MAX = 60;

    /** @return list<mixed> */
    public static function name(): array
    {
        return ['required', 'string', 'max:80', self::noControlCharacters()];
    }

    /**
     * A20: city is a typed label; the caller trims it and turns empty into null first.
     *
     * @return list<mixed>
     */
    public static function city(): array
    {
        return ['present', 'nullable', 'string', 'max:'.self::CITY_MAX, self::noControlCharacters()];
    }

    /** Control characters (NUL, line breaks, escapes) never belong in a label. */
    private static function noControlCharacters(): Closure
    {
        return function (string $attribute, mixed $value, Closure $fail) {
            if (is_string($value) && preg_match('/\p{Cc}/u', $value) === 1) {
                $fail('Use letters, spaces and punctuation only.');
            }
        };
    }

    /**
     * A20: an upper-case ISO 3166-1 alpha-2 code from the shared list, or null.
     *
     * @return list<mixed>
     */
    public static function countryCode(): array
    {
        return ['present', 'nullable', 'string', function (string $attribute, mixed $value, Closure $fail) {
            if (! is_string($value) || ! Countries::isCode($value)) {
                $fail('Choose a country from the list.');
            }
        }];
    }
}
