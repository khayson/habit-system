<?php

namespace App\Application\Mutations;

use App\Domain\Calendar\LocalDate;
use DateTimeImmutable;

/** A validated mutation envelope (spec 07). `raw` is the client's original object, hashed for idempotency. */
final readonly class Mutation
{
    /**
     * @param  array<string, mixed>  $payload
     * @param  array<string, mixed>  $raw
     */
    public function __construct(
        public string $mutationId,
        public string $entity,
        public string $entityId,
        public string $operation,
        public ?int $baseVersion,
        /** Full client precision (fractional seconds kept). */
        public DateTimeImmutable $occurredAt,
        public ?string $capturedTimezone,
        public ?LocalDate $localDateHint,
        public array $payload,
        public array $raw,
    ) {}
}
