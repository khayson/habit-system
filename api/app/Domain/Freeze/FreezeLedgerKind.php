<?php

namespace App\Domain\Freeze;

enum FreezeLedgerKind: string
{
    case Grant = 'grant';
    case Spend = 'spend';
    case Refund = 'refund';
}
