<?php

namespace App\Domain\Freeze;

/** One append-only freeze_ledger row. UNIQUE(user_id, source_key) makes writes idempotent. */
final readonly class FreezeLedgerEntry
{
    public function __construct(
        public FreezeLedgerKind $kind,
        public int $delta,
        public string $reason,
        public string $sourceKey,
    ) {}
}
