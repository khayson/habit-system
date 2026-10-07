<?php

namespace App\Application\Mutations;

final readonly class MutationContext
{
    /**
     * @param  list<string>|null  $capabilities  habit types the client declared; null = legacy client (built-ins)
     */
    public function __construct(
        public string $userId,
        public ?string $deviceId,
        public Mutation $mutation,
        public ?array $capabilities,
    ) {}
}
