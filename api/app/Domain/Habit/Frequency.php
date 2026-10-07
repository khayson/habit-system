<?php

namespace App\Domain\Habit;

use App\Domain\Calendar\LocalDate;
use InvalidArgumentException;

/**
 * A schedule (spec 02): daily {}; weekdays {days:[1..7]}; weekly_count {count:1..7};
 * interval {every_n_days:1..365, anchor_date}.
 */
final readonly class Frequency
{
    /**
     * @param  list<int>  $days
     */
    private function __construct(
        public FrequencyType $type,
        public array $days = [],
        public int $count = 0,
        public int $everyNDays = 0,
        public ?LocalDate $anchorDate = null,
    ) {}

    public static function daily(): self
    {
        return new self(FrequencyType::Daily);
    }

    /** @param list<int> $days 1 = Monday … 7 = Sunday */
    public static function weekdays(array $days): self
    {
        $unique = array_values(array_unique($days));
        if ($days === [] || count($unique) !== count($days)) {
            throw new InvalidArgumentException('Weekdays must be a non-empty list of unique days.');
        }
        foreach ($days as $day) {
            if ($day < 1 || $day > 7) {
                throw new InvalidArgumentException('Weekdays are 1 (Monday) to 7 (Sunday).');
            }
        }
        sort($unique);

        return new self(FrequencyType::Weekdays, days: $unique);
    }

    public static function weeklyCount(int $count): self
    {
        if ($count < 1 || $count > 7) {
            throw new InvalidArgumentException('A weekly target is 1 to 7 days.');
        }

        return new self(FrequencyType::WeeklyCount, count: $count);
    }

    public static function interval(int $everyNDays, LocalDate $anchorDate): self
    {
        if ($everyNDays < 1 || $everyNDays > 365) {
            throw new InvalidArgumentException('An interval is 1 to 365 days.');
        }

        return new self(FrequencyType::Interval, everyNDays: $everyNDays, anchorDate: $anchorDate);
    }

    /**
     * From the stored `frequency_type` + `frequency_config` pair.
     *
     * @param  array<string, mixed>  $config
     */
    public static function fromArray(string $type, array $config): self
    {
        return match (FrequencyType::tryFrom($type)) {
            FrequencyType::Daily => self::daily(),
            FrequencyType::Weekdays => self::weekdays(self::intList($config['days'] ?? null)),
            FrequencyType::WeeklyCount => self::weeklyCount(self::int($config['count'] ?? null)),
            FrequencyType::Interval => self::interval(
                self::int($config['every_n_days'] ?? null),
                LocalDate::fromString(is_string($config['anchor_date'] ?? null) ? $config['anchor_date'] : ''),
            ),
            null => throw new InvalidArgumentException("Unknown frequency type: {$type}"),
        };
    }

    /**
     * Canonical `frequency_config`: only the keys the type defines, days sorted (A29). This is
     * what is stored and sent, never the client's raw object.
     *
     * @return array<string, mixed>
     */
    public function toArray(): array
    {
        return match ($this->type) {
            FrequencyType::Daily => [],
            FrequencyType::Weekdays => ['days' => $this->days],
            FrequencyType::WeeklyCount => ['count' => $this->count],
            FrequencyType::Interval => ['every_n_days' => $this->everyNDays, 'anchor_date' => $this->anchorDate?->toString()],
        };
    }

    public function isWeekly(): bool
    {
        return $this->type === FrequencyType::WeeklyCount;
    }

    /** For day-based schedules: is this local date a scheduled period? */
    public function schedules(LocalDate $date): bool
    {
        return match ($this->type) {
            FrequencyType::Daily => true,
            FrequencyType::Weekdays => in_array($date->isoWeekday(), $this->days, true),
            FrequencyType::Interval => $this->anchorDate !== null
                && ! $date->isBefore($this->anchorDate)
                && $this->anchorDate->daysUntil($date) % $this->everyNDays === 0,
            FrequencyType::WeeklyCount => false,
        };
    }

    /** Streak unit shown to users: days, scheduled periods, or weeks (spec 02, 08). */
    public function streakUnit(): string
    {
        return match ($this->type) {
            FrequencyType::Daily => 'days',
            FrequencyType::Weekdays, FrequencyType::Interval => 'periods',
            FrequencyType::WeeklyCount => 'weeks',
        };
    }

    private static function int(mixed $value): int
    {
        if (! is_int($value)) {
            throw new InvalidArgumentException('Expected an integer in frequency_config.');
        }

        return $value;
    }

    /** @return list<int> */
    private static function intList(mixed $value): array
    {
        if (! is_array($value) || ! array_is_list($value)) {
            throw new InvalidArgumentException('Expected a list of integers in frequency_config.');
        }

        return array_map(self::int(...), $value);
    }
}
