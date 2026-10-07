<?php

namespace App\Domain\Habit;

/**
 * The stored state of one habit-day (A21): `value` is the scalar the rule evaluates (binary 0/1,
 * quantity thousandths, duration seconds, checklist items done, …); `detail` holds type-specific
 * state such as checklist item states. Built-in types leave `detail` empty.
 */
final readonly class LogState
{
    /**
     * @param  array<string, mixed>  $detail
     */
    public function __construct(
        public int $value,
        public array $detail = [],
    ) {}

    public static function empty(): self
    {
        return new self(0);
    }

    public function withValue(int $value): self
    {
        return new self($value, $this->detail);
    }

    /**
     * Same desired state (S7). Values are integer units, so comparing them is exact (it is the
     * same comparison StoredDecimal's storage form would give); `detail` is compared as
     * canonical JSON, so key order never matters but list order does.
     */
    public function equals(self $other): bool
    {
        return $this->value === $other->value
            && self::canonicalJson($this->detail) === self::canonicalJson($other->detail);
    }

    private static function canonicalJson(mixed $value): string
    {
        return json_encode(self::canonical($value), JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION);
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
