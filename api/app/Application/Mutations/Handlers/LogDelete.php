<?php

namespace App\Application\Mutations\Handlers;

use App\Application\Journal\ChangeJournal;
use App\Application\Mutations\HandlerResult;
use App\Application\Mutations\MutationContext;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use App\Support\UtcTime;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use stdClass;

/**
 * log.delete: version-checked soft tombstone (spec 03, 06). Falls back to habit_id + log_date
 * when the entity id is unknown (A29). The row is never physically deleted;
 * the journal records the delete with its new version.
 */
final readonly class LogDelete
{
    public function __construct(
        private ChangeJournal $journal,
        private EntityPresenter $presenter,
        private Clock $clock,
    ) {}

    public function handle(MutationContext $ctx): HandlerResult
    {
        $m = $ctx->mutation;
        if ($m->baseVersion === null) {
            throw ValidationException::withMessages(['base_version' => ['base_version is required.']]);
        }

        // A29: after a merge the client may hold an id the server never saw; fall back to the
        // natural key (habit_id + log_date), still owner-scoped.
        $log = LogWrites::find($ctx->userId, $m->entityId) ?? $this->findByNaturalKey($ctx->userId, $m->payload);
        if ($log === null) {
            throw new ApiException(404, 'not_found', 'Not found.');
        }
        $typeKey = (string) DB::table('habits')->where('id', $log->habit_id)->value('type');

        if ($log->deleted_at !== null) {
            if ($m->baseVersion === (int) $log->version) {
                return new HandlerResult('habit_log', (string) $log->id, (int) $log->version, (string) $log->log_date);
            }
            throw ApiException::resourceDeleted('habit_log', (string) $log->id, (int) $log->version);
        }
        if ($m->baseVersion !== (int) $log->version) {
            throw ApiException::versionConflict((string) $log->id, $m->baseVersion, (int) $log->version, $this->presenter->log($log, $typeKey));
        }

        $now = UtcTime::format($this->clock->now());
        $version = (int) $log->version + 1;
        DB::table('habit_logs')->where('id', $log->id)->update([
            'deleted_at' => $now,
            'completed_at' => null,
            'version' => $version,
            'updated_at' => $now,
        ]);
        LogWrites::markStreakDirty((string) $log->habit_id, (string) $log->log_date, $now);
        $row = DB::table('habit_logs')->where('id', $log->id)->first();
        $this->journal->append($ctx->userId, 'habit_log', (string) $log->id, 'delete', $version, $this->presenter->log($row ?? $log, $typeKey));

        return new HandlerResult('habit_log', (string) $log->id, $version, (string) $log->log_date);
    }

    /** @param array<string, mixed> $payload */
    private function findByNaturalKey(string $userId, array $payload): ?stdClass
    {
        $habitId = $payload['habit_id'] ?? null;
        $logDate = $payload['log_date'] ?? null;
        if (! is_string($habitId) || ! Str::isUuid($habitId) || ! is_string($logDate)
            || preg_match('/^\d{4}-\d{2}-\d{2}$/', $logDate) !== 1) {
            return null;
        }

        return DB::table('habit_logs')
            ->where('user_id', $userId)
            ->where('habit_id', strtolower($habitId))
            ->where('log_date', $logDate)
            ->lockForUpdate()
            ->first();
    }
}
