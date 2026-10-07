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
use Illuminate\Validation\ValidationException;

/**
 * log.delete: version-checked soft tombstone (spec 03, 06). The row is never physically deleted;
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

        $log = LogWrites::find($ctx->userId, $m->entityId);
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
}
