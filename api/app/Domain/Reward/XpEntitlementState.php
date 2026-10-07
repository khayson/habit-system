<?php

namespace App\Domain\Reward;

enum XpEntitlementState: string
{
    case Active = 'active';
    case Reversed = 'reversed';
}
