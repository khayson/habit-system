<?php

namespace App\Domain\Habit;

/**
 * Exact conversion between integer units and the numeric(12,3) storage form, without floats.
 * `$unitDecimals` is how many decimal places one unit represents: 3 for thousandths, 0 for
 * whole units (seconds, 0/1, item counts).
 */
final class StoredDecimal
{
    private const int STORED_DECIMALS = 3;

    public static function fromUnits(int $units, int $unitDecimals): string
    {
        $scaled = $units * 10 ** (self::STORED_DECIMALS - $unitDecimals);

        return intdiv($scaled, 1000).'.'.str_pad((string) ($scaled % 1000), 3, '0', STR_PAD_LEFT);
    }

    /** @throws InvalidHabitValue */
    public static function toUnits(string $stored, int $unitDecimals): int
    {
        if (preg_match('/^(\d{1,9})(?:\.(\d{1,3}))?$/', $stored, $m) !== 1) {
            throw new InvalidHabitValue("Unreadable stored value: {$stored}");
        }
        $fraction = str_pad($m[2] ?? '', self::STORED_DECIMALS, '0');
        if (substr($fraction, $unitDecimals) !== str_repeat('0', self::STORED_DECIMALS - $unitDecimals)) {
            throw new InvalidHabitValue("Stored value {$stored} has more precision than the type allows.");
        }

        return (int) $m[1] * 10 ** $unitDecimals + (int) substr($fraction, 0, $unitDecimals);
    }
}
