<?php

namespace App\Domain\Habit;

use DomainException;

/** Maps to 422 unsupported_type when a client creates a type it has not declared (A21). */
final class UnknownHabitType extends DomainException
{
    public function __construct(public readonly string $type)
    {
        parent::__construct("Unknown habit type: {$type}");
    }
}
