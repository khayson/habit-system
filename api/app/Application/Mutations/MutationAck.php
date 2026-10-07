<?php

namespace App\Application\Mutations;

/**
 * Per-mutation acknowledgement in a /sync response. HTTP 200 never implies every mutation was
 * accepted (spec 07). `error` reuses the HTTP error object shapes exactly (A25).
 */
final readonly class MutationAck
{
    public const string ACCEPTED = 'accepted';

    public const string CONFLICT = 'conflict';

    public const string REJECTED = 'rejected';

    public const string DEPENDENCY_PENDING = 'dependency_pending';

    /**
     * @param  array<string, mixed>|null  $error
     */
    public function __construct(
        public ?string $mutationId,
        public string $status,
        public bool $duplicate = false,
        public ?string $entity = null,
        public ?string $entityId = null,
        public ?int $version = null,
        public ?string $resolvedDate = null,
        public ?array $error = null,
    ) {}

    /** @return array<string, mixed> */
    public function toArray(): array
    {
        return array_filter([
            'mutation_id' => $this->mutationId,
            'status' => $this->status,
            'duplicate' => $this->duplicate,
            'entity' => $this->entity,
            'entity_id' => $this->entityId,
            'version' => $this->version,
            'resolved_date' => $this->resolvedDate,
            'error' => $this->error,
        ], fn ($value, $key) => $value !== null || in_array($key, ['mutation_id', 'status', 'duplicate'], true), ARRAY_FILTER_USE_BOTH);
    }

    /** @param array<string, mixed> $stored */
    public static function fromStored(array $stored, bool $duplicate): self
    {
        return new self(
            $stored['mutation_id'] ?? null,
            (string) $stored['status'],
            $duplicate,
            $stored['entity'] ?? null,
            $stored['entity_id'] ?? null,
            $stored['version'] ?? null,
            $stored['resolved_date'] ?? null,
            $stored['error'] ?? null,
        );
    }
}
