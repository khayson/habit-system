<?php

namespace App\Domain\Habit;

use DomainException;

/** Maps to 422 unsupported_operation (A21, reserved code). */
final class UnsupportedOperation extends DomainException
{
    public function __construct(public readonly string $type, public readonly string $operation)
    {
        parent::__construct("Habit type {$type} does not support {$operation}");
    }
}
