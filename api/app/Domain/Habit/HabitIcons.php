<?php

namespace App\Domain\Habit;

/**
 * A53: a habit's chosen icon. The key is a Hugeicons name in kebab form; the server checks only
 * its shape, so a newer app's icon set syncs to an older server. The keyword table is
 * contract-fixtures/habit/icons.json's (a test keeps them equal); the app suggests with the same
 * table and the one-time backfill uses it.
 */
final class HabitIcons
{
    public const string KEY_PATTERN = '/^[a-z0-9]+(-[a-z0-9]+)*$/';

    public const int MAX_LENGTH = 64;

    /** Tried in order: the first entry with a prefix that starts any word of the name wins. */
    public const array KEYWORDS = [
        [['water'], 'glass-water'],
        [['read'], 'book-open-01'],
        [['book'], 'book-02'],
        [['meditat'], 'yoga-02'],
        [['run'], 'workout-run'],
        [['walk'], 'walking'],
        [['sleep'], 'bed'],
        [['journal'], 'notebook'],
        [['pray'], 'hand-prayer'],
        [['gym', 'workout'], 'dumbbell-01'],
        [['yoga'], 'yoga-01'],
        [['code', 'coding'], 'code'],
        [['study'], 'study-desk'],
    ];

    /** The keyword table's icon for a habit name, or null. */
    public static function suggest(string $name): ?string
    {
        $words = preg_split('/[^\p{L}\p{N}]+/u', mb_strtolower($name), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        foreach (self::KEYWORDS as [$prefixes, $icon]) {
            foreach ($words as $word) {
                foreach ($prefixes as $prefix) {
                    if (str_starts_with($word, $prefix)) {
                        return $icon;
                    }
                }
            }
        }

        return null;
    }

    /** @return list<string> the validation rules for an icon field */
    public static function rules(): array
    {
        return ['nullable', 'string', 'max:'.self::MAX_LENGTH, 'regex:'.self::KEY_PATTERN];
    }
}
