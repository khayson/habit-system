<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * A spec-defined API error with a stable machine code. Rendered by ApiExceptionRenderer.
 */
class ApiException extends RuntimeException
{
    /**
     * @param  array<string, mixed>  $extra  extra keys inside the `error` object
     * @param  array<string, string>  $headers
     */
    public function __construct(
        public readonly int $status,
        public readonly string $errorCode,
        string $message,
        public readonly array $extra = [],
        public readonly array $headers = [],
    ) {
        parent::__construct($message);
    }

    /**
     * 409: stale base_version. `$current` is the canonical current resource.
     *
     * @param  array<string, mixed>  $current
     */
    public static function versionConflict(string $resourceId, int $expectedVersion, int $currentVersion, array $current): self
    {
        return new self(409, 'version_conflict', 'This item changed on another device.', [
            'resource_id' => $resourceId,
            'expected_version' => $expectedVersion,
            'current_version' => $currentVersion,
            'current' => $current,
        ]);
    }

    /** 409: same mutation_id re-sent with a different payload hash. */
    public static function idempotencyMismatch(): self
    {
        return new self(409, 'idempotency_mismatch', 'This change was already sent with different content.');
    }

    /**
     * 409: target is tombstoned. `$entity` is the entity type (e.g. habit_log); `$tombstoneVersion`
     * is needed for a reviewed restore and travels as `current_version` (docs/api-error-codes.md).
     */
    public static function resourceDeleted(string $entity, string $resourceId, int $tombstoneVersion): self
    {
        return new self(409, 'resource_deleted', 'This item was deleted on another device.', [
            'entity' => $entity,
            'resource_id' => $resourceId,
            'current_version' => $tombstoneVersion,
        ]);
    }

    /** 410: sync cursor older than journal retention. */
    public static function cursorExpired(): self
    {
        return new self(410, 'cursor_expired', 'A full refresh is needed. Your unsent changes are kept.');
    }
}
