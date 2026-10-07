<?php

namespace App\Domain\Habit;

use App\Domain\Habit\Types\BinaryType;
use App\Domain\Habit\Types\DurationType;
use App\Domain\Habit\Types\QuantityType;
use InvalidArgumentException;

/** The single place habit types are known (A21, invariant 14). */
final class HabitTypeRegistry
{
    /** @var array<string, HabitType> */
    private array $types = [];

    public function __construct(HabitType ...$types)
    {
        foreach ($types as $type) {
            $this->register($type);
        }
    }

    /** binary, quantity and duration: the spec's three types. */
    public static function withBuiltins(): self
    {
        return new self(new BinaryType, new QuantityType, new DurationType);
    }

    public function register(HabitType $type): void
    {
        if (isset($this->types[$type->key()])) {
            throw new InvalidArgumentException("Habit type already registered: {$type->key()}");
        }
        $this->types[$type->key()] = $type;
    }

    /** @throws UnknownHabitType */
    public function get(string $key): HabitType
    {
        return $this->types[$key] ?? throw new UnknownHabitType($key);
    }

    public function has(string $key): bool
    {
        return isset($this->types[$key]);
    }

    /** @return list<string> */
    public function keys(): array
    {
        return array_keys($this->types);
    }
}
