<?php

namespace App\Application\Mutations;

final readonly class HandlerResult
{
    public function __construct(
        public string $entity,
        public string $entityId,
        public int $version,
        public ?string $resolvedDate = null,
        // A43: the XP this mutation moved (+10 or -10), null when it moved none.
        public ?int $xpDelta = null,
    ) {}
}
