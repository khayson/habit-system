<?php

namespace App\Application\Sync;

use App\Application\Calendar\UserCalendar;
use App\Application\Periods\PeriodCloser;
use App\Application\Presenters\EntityPresenter;
use App\Domain\Clock;
use App\Exceptions\ApiException;
use Illuminate\Support\Facades\DB;
use stdClass;

/**
 * GET /sync/bootstrap (A2): a paged snapshot for a fresh install, a new device or after 410.
 * The first page pins snapshot_seq; pages read live rows, so a row may be newer than the snapshot.
 * That is safe: the client then calls /sync from snapshot_seq and replays idempotently (a change
 * applies only if its version is >= the local one).
 *
 * Pages: user (first page only) → habits (with definitions and ranges) → logs, including
 * tombstones so deletions reconcile → A32 derived entities in A31's `entities` array:
 * habit_progress for every habit, then period_evaluation for the last 400 days.
 */
final readonly class BootstrapService
{
    public const int DEFAULT_LIMIT = 200;

    public const int MAX_LIMIT = 500;

    private const string PHASE_HABITS = 'habits';

    private const string PHASE_LOGS = 'logs';

    private const string PHASE_PROGRESS = 'progress';

    private const string PHASE_EVALUATIONS = 'evaluations';

    /** A32: older evaluations come from GET /habits/{id}/heatmap when online. */
    public const int EVALUATION_DAYS = 400;

    public function __construct(
        private EntityPresenter $presenter,
        private PeriodCloser $closer,
        private Clock $clock,
    ) {}

    /** @return array<string, mixed> */
    public function page(string $userId, ?string $cursor, int $limit): array
    {
        if ($cursor === null) {
            // A10: derived entities are brought up to date before a snapshot is taken.
            $this->closer->closeUserIfStale($userId);
            $state = ['snap' => (int) DB::table('users')->where('id', $userId)->value('change_seq'), 'phase' => self::PHASE_HABITS, 'after' => null];
            $first = true;
        } else {
            // A29: an unusable page cursor means "start the bootstrap again".
            $state = SyncCursor::decode($cursor, $userId, 'b') ?? throw ApiException::cursorExpired();
            $first = false;
        }

        $user = $first ? $this->presenter->user(DB::table('users')->where('id', $userId)->first() ?? (object) []) : null;
        $habits = [];
        $logs = [];
        $entities = [];
        $next = null;

        if ($state['phase'] === self::PHASE_HABITS) {
            $rows = DB::table('habits')->where('user_id', $userId)
                ->when($state['after'] !== null, fn ($q) => $q->where('id', '>', $state['after']))
                ->orderBy('id')->limit($limit + 1)->get();
            $habits = $rows->take($limit)->map(fn (stdClass $h) => $this->presenter->habit($h))->values()->all();
            $next = $rows->count() > $limit
                ? ['phase' => self::PHASE_HABITS, 'after' => (string) $rows->get($limit - 1)?->id]
                : ['phase' => self::PHASE_LOGS, 'after' => null];
        } elseif ($state['phase'] === self::PHASE_LOGS) {
            $rows = DB::table('habit_logs')
                ->join('habits', 'habits.id', '=', 'habit_logs.habit_id')
                ->where('habit_logs.user_id', $userId)
                ->when($state['after'] !== null, fn ($q) => $q->where('habit_logs.id', '>', $state['after']))
                ->orderBy('habit_logs.id')->limit($limit + 1)
                ->get(['habit_logs.*', 'habits.type as habit_type']);
            $logs = $rows->take($limit)->map(fn (stdClass $l) => $this->presenter->log($l, (string) $l->habit_type))->values()->all();
            $next = $rows->count() > $limit
                ? ['phase' => self::PHASE_LOGS, 'after' => (string) $rows->get($limit - 1)?->id]
                : ['phase' => self::PHASE_PROGRESS, 'after' => null];
        } elseif ($state['phase'] === self::PHASE_PROGRESS) {
            $rows = DB::table('habit_streak_cache')
                ->join('habits', 'habits.id', '=', 'habit_streak_cache.habit_id')
                ->where('habits.user_id', $userId)
                ->when($state['after'] !== null, fn ($q) => $q->where('habit_streak_cache.habit_id', '>', $state['after']))
                ->orderBy('habit_streak_cache.habit_id')->limit($limit + 1)
                ->get(['habit_streak_cache.*']);
            $entities = $rows->take($limit)->map(fn (stdClass $c) => [
                'entity' => 'habit_progress',
                'id' => $c->habit_id,
                'version' => (int) $c->version,
                'payload' => $this->presenter->habitProgress($c),
            ])->values()->all();
            $next = $rows->count() > $limit
                ? ['phase' => self::PHASE_PROGRESS, 'after' => (string) $rows->get($limit - 1)?->habit_id]
                : ['phase' => self::PHASE_EVALUATIONS, 'after' => null];
        } else {
            $since = UserCalendar::timeline($userId)->localDateAt($this->clock->now())->addDays(-self::EVALUATION_DAYS);
            $rows = DB::table('period_evaluations')
                ->where('user_id', $userId)
                ->where('start_date', '>=', $since->toString())
                ->when($state['after'] !== null, fn ($q) => $q->where('id', '>', $state['after']))
                ->orderBy('id')->limit($limit + 1)->get();
            $entities = $rows->take($limit)->map(fn (stdClass $e) => [
                'entity' => 'period_evaluation',
                'id' => $e->id,
                'version' => (int) $e->revision,
                'payload' => $this->presenter->periodEvaluation($e),
            ])->values()->all();
            $next = $rows->count() > $limit ? ['phase' => self::PHASE_EVALUATIONS, 'after' => (string) $rows->get($limit - 1)?->id] : null;
        }

        $snap = (int) $state['snap'];

        return [
            'user' => $user,
            'habits' => $habits,
            'logs' => $logs,
            // A31: entity types added after v1 (here A32's derived entities).
            'entities' => $entities,
            'has_more' => $next !== null,
            'next_cursor' => $next === null ? null : SyncCursor::encode($userId, 'b', ['snap' => $snap, ...$next]),
            // Only on the last page: continue with POST /sync from here.
            'sync_cursor' => $next === null ? SyncCursor::forSeq($userId, $snap) : null,
            'snapshot_seq' => $snap,
        ];
    }
}
