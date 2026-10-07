<?php

namespace App\Application\Mutations;

final readonly class HandlerResult
{
    public function __construct(
        public string $entity,
        public string $entityId,
        public int $version,
        public ?string $resolvedDate = null,
    ) {}
}
