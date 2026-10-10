<?php

namespace App\Domain\Habit;

use DomainException;

/** A34: an edit or a log write on an archived habit. Restore it first. */
final class HabitArchived extends DomainException
{
    public function __construct(public readonly string $habitId)
    {
        parent::__construct('The habit is archived.');
    }
}
