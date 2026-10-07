<?php

namespace App\Domain\Calendar;

use InvalidArgumentException;
use Stringable;

/**
 * A business date (`DATE`): a calendar day with no time and no zone. Stored as days since
 * 1970-01-01 so arithmetic never touches time zones or DST.
 */
final readonly class LocalDate implements Stringable
{
    private function __construct(public int $epochDay) {}

    public static function fromString(string $value): self
    {
        if (preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $value, $m) !== 1 || ! checkdate((int) $m[2], (int) $m[3], (int) $m[1])) {
            throw new InvalidArgumentException("Invalid local date: {$value}");
        }

        return new self(self::daysFromCivil((int) $m[1], (int) $m[2], (int) $m[3]));
    }

    public static function fromEpochDay(int $epochDay): self
    {
        return new self($epochDay);
    }

    public static function of(int $year, int $month, int $day): self
    {
        return self::fromString(sprintf('%04d-%02d-%02d', $year, $month, $day));
    }

    public function toString(): string
    {
        [$y, $m, $d] = self::civilFromDays($this->epochDay);

        return sprintf('%04d-%02d-%02d', $y, $m, $d);
    }

    public function __toString(): string
    {
        return $this->toString();
    }

    public function addDays(int $days): self
    {
        return new self($this->epochDay + $days);
    }

    /** 1 = Monday … 7 = Sunday (spec: days_of_week). */
    public function isoWeekday(): int
    {
        // 1970-01-01 was a Thursday (4).
        return (($this->epochDay % 7) + 7 + 3) % 7 + 1;
    }

    /** The Monday that starts this date's local week (A3, spec 08). */
    public function mondayOfWeek(): self
    {
        return $this->addDays(1 - $this->isoWeekday());
    }

    /** `YYYY-MM`. */
    public function yearMonth(): string
    {
        return substr($this->toString(), 0, 7);
    }

    /** Whole days from this date to $other (positive when $other is later). */
    public function daysUntil(self $other): int
    {
        return $other->epochDay - $this->epochDay;
    }

    public function equals(self $other): bool
    {
        return $this->epochDay === $other->epochDay;
    }

    public function isBefore(self $other): bool
    {
        return $this->epochDay < $other->epochDay;
    }

    public function isAfter(self $other): bool
    {
        return $this->epochDay > $other->epochDay;
    }

    public function compareTo(self $other): int
    {
        return $this->epochDay <=> $other->epochDay;
    }

    public static function max(self $a, self $b): self
    {
        return $a->isAfter($b) ? $a : $b;
    }

    public static function min(self $a, self $b): self
    {
        return $a->isBefore($b) ? $a : $b;
    }

    // Howard Hinnant's civil-calendar algorithms (proleptic Gregorian, integer only).
    private static function daysFromCivil(int $y, int $m, int $d): int
    {
        $y -= $m <= 2 ? 1 : 0;
        $era = intdiv($y >= 0 ? $y : $y - 399, 400);
        $yoe = $y - $era * 400;
        $doy = intdiv(153 * ($m + ($m > 2 ? -3 : 9)) + 2, 5) + $d - 1;
        $doe = $yoe * 365 + intdiv($yoe, 4) - intdiv($yoe, 100) + $doy;

        return $era * 146097 + $doe - 719468;
    }

    /**
     * @return array{int, int, int}
     */
    private static function civilFromDays(int $z): array
    {
        $z += 719468;
        $era = intdiv($z >= 0 ? $z : $z - 146096, 146097);
        $doe = $z - $era * 146097;
        $yoe = intdiv($doe - intdiv($doe, 1460) + intdiv($doe, 36524) - intdiv($doe, 146096), 365);
        $y = $yoe + $era * 400;
        $doy = $doe - (365 * $yoe + intdiv($yoe, 4) - intdiv($yoe, 100));
        $mp = intdiv(5 * $doy + 2, 153);
        $d = $doy - intdiv(153 * $mp + 2, 5) + 1;
        $m = $mp + ($mp < 10 ? 3 : -9);

        return [$y + ($m <= 2 ? 1 : 0), $m, $d];
    }
}
