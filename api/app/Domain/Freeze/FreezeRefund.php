<?php

namespace App\Domain\Freeze;

final readonly class FreezeRefund
{
    public function __construct(
        /** delta 1, or a zero-delta cap_reached audit row. */
        public FreezeLedgerEntry $entry,
        public FreezeUsage $usage,
        public int $balance,
    ) {}
}
