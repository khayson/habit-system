<?php

namespace App\Domain\Freeze;

enum FreezeOutcome: string
{
    case Spent = 'spent';
    case AlreadyUsed = 'already_used';
    case PolicyDisabled = 'policy_disabled';
    case NoBalance = 'no_balance';
    case PeriodOpen = 'period_open';
}
