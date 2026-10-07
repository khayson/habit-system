<?php

namespace App\Domain\Habit;

use App\Domain\Calendar\LocalDate;
use InvalidArgumentException;

/**
 * One row of habit_definition_versions, the authority for type, target, unit, category and
 * frequency (A4). Applies from `effectiveDate` until the next version.
 */
final readonly class DefinitionVersion
{
    public const array CATEGORIES = ['health', 'mindfulness', 'learning', 'productivity', 'other'];

    /**
     * @param  array<string, mixed>  $config
     */
    public function __construct(
        public int $version,
        public LocalDate $effectiveDate,
        public string $type,
        /** Target in the type's units (see HabitType). */
        public int $target,
        public ?string $unit,
        public string $category,
        public Frequency $frequency,
        /** Type-specific settings (A21), e.g. checklist item ids. Empty for built-in types. */
        public array $config = [],
    ) {
        if ($version < 1) {
            throw new InvalidArgumentException('Definition versions start at 1.');
        }
        if (! in_array($category, self::CATEGORIES, true)) {
            throw new InvalidArgumentException("Unknown category: {$category}");
        }
        if ($target <= 0) {
            throw new InvalidArgumentException('A target is greater than zero.');
        }
    }
}
