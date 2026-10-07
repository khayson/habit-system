<?php

namespace App\Domain\Freeze;

/** Result of one closure pass: write ledger + usages + journal and recompute streaks atomically. */
final readonly class FreezeClosure
{
    /**
     * @param  list<FreezeDecision>  $decisions  in evaluation order (A8)
     * @param  list<FreezeLedgerEntry>  $ledger
     * @param  list<FreezeUsage>  $usages  new usages
     */
    public function __construct(
        public array $decisions,
        public array $ledger,
        public array $usages,
        public int $balance,
    ) {}
}
