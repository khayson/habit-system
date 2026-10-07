<?php

namespace App\Domain\Freeze;

enum FreezeUsageState: string
{
    case Active = 'active';
    case Refunded = 'refunded';
}
