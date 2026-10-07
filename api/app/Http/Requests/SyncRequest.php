<?php

namespace App\Http\Requests;

use App\Application\Sync\SyncService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\PostTooLargeException;

/**
 * POST /sync envelope. Each mutation is validated on its own by the MutationApplier so one bad
 * mutation is rejected in its ack instead of failing the batch.
 */
final class SyncRequest extends FormRequest
{
    protected function prepareForValidation(): void
    {
        $mutations = $this->input('mutations');
        if (is_array($mutations) && count($mutations) > SyncService::MAX_MUTATIONS) {
            throw new PostTooLargeException('Too many mutations in one batch.');
        }
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'device_id' => ['required', 'uuid'],
            'cursor' => ['nullable', 'string', 'max:1024'],
            'pull_limit' => ['nullable', 'integer', 'min:1', 'max:'.SyncService::MAX_PULL_LIMIT],
            'mutations' => ['present', 'array', 'list'],
            'mutations.*' => ['array'],
        ];
    }

    /**
     * Habit types the client declared (A21), from `X-Capabilities: type.binary, type.quantity`.
     * Null when the header is absent: a legacy client, limited to the built-in types.
     * ASSUMPTION(A2a-capabilities): header format.
     *
     * @return list<string>|null
     */
    public function capabilities(): ?array
    {
        $header = $this->header('X-Capabilities');
        if (! is_string($header) || trim($header) === '') {
            return null;
        }
        $types = [];
        foreach (explode(',', $header) as $token) {
            $token = trim($token);
            if (str_starts_with($token, 'type.')) {
                $types[] = substr($token, 5);
            }
        }

        return $types;
    }
}
