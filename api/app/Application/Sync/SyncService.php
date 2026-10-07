<?php

namespace App\Application\Sync;

use App\Application\Habits\HabitRepository;
use App\Application\Mutations\MutationApplier;
use App\Exceptions\ApiException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use stdClass;

/**
 * POST /sync (spec 07): apply each mutation independently, then return a bounded, server-ordered
 * page of journal changes after the cursor. The cursor advances only through `next_cursor`.
 */
final readonly class SyncService
{
    public const int DEFAULT_PULL_LIMIT = 200;

    public const int MAX_PULL_LIMIT = 500;

    public const int MAX_MUTATIONS = 100;

    public function __construct(private MutationApplier $applier) {}

    /**
     * @param  list<array<mixed>>  $mutations
     * @param  list<string>|null  $capabilities
     * @return array{acks: list<array<string, mixed>>, changes: list<array<string, mixed>>, next_cursor: string, has_more: bool}
     */
    public function sync(string $userId, string $deviceId, ?string $cursor, int $pullLimit, array $mutations, ?array $capabilities): array
    {
        // Validate the cursor before applying anything, so a bad request changes nothing.
        $after = $this->position($userId, $cursor);

        $acks = array_map(
            fn (array $mutation): array => $this->applier->apply($userId, $deviceId, $mutation, $capabilities)->toArray(),
            $mutations,
        );

        return ['acks' => $acks, ...$this->pull($userId, $after, $pullLimit)];
    }

    /**
     * Changes with seq > $after, oldest first. `has_more` comes from fetching one extra row.
     *
     * @return array{changes: list<array<string, mixed>>, next_cursor: string, has_more: bool}
     */
    public function pull(string $userId, int $after, int $limit): array
    {
        $rows = DB::table('server_changes')
            ->where('user_id', $userId)
            ->where('seq', '>', $after)
            ->orderBy('seq')
            ->limit($limit + 1)
            ->get();

        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit);
        $last = $page->last();

        return [
            'changes' => array_values($page->map(fn (stdClass $row) => [
                'seq' => (int) $row->seq,
                'entity' => (string) $row->entity_type,
                'id' => (string) $row->entity_id,
                'operation' => (string) $row->operation,
                'version' => (int) $row->version,
                'payload' => (object) HabitRepository::json($row->payload),
            ])->all()),
            'next_cursor' => SyncCursor::forSeq($userId, $last === null ? $after : (int) $last->seq),
            'has_more' => $hasMore,
        ];
    }

    /** The seq a cursor stands for; a null cursor starts from the beginning of the journal. */
    public function position(string $userId, ?string $cursor): int
    {
        if ($cursor === null) {
            return 0;
        }
        $seq = SyncCursor::seqOf($cursor, $userId);
        $head = (int) DB::table('users')->where('id', $userId)->value('change_seq');
        if ($seq === null || $seq > $head) {
            throw ValidationException::withMessages(['cursor' => ['The cursor is not valid for this account.']]);
        }

        // Journal rows older than retention are pruned (180 days); a cursor before the oldest
        // retained row can no longer be served incrementally.
        $oldest = DB::table('server_changes')->where('user_id', $userId)->min('seq');
        if ($oldest !== null && $seq < (int) $oldest - 1) {
            throw ApiException::cursorExpired();
        }

        return $seq;
    }
}
