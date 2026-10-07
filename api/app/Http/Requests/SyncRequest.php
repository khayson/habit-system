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
     * A29: what a client that sends no X-Capabilities header declares. Such a client predates
     * the registry, i.e. it is a spec-v1 client, and spec v1 has exactly these three types.
     */
    public const array BASELINE_TYPES = ['binary', 'quantity', 'duration'];

    /**
     * Habit types the client declared (A21), from `X-Capabilities: type.binary, type.quantity`.
     * An absent or empty header means the baseline set, never "no restriction" (A29).
     *
     * @return list<string>
     */
    public function capabilities(): array
    {
        $header = $this->header('X-Capabilities');
        if (! is_string($header) || trim($header) === '') {
            return self::BASELINE_TYPES;
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
