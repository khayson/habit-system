<?php

namespace App\Application\Insights;

use App\Application\Calendar\UserCalendar;
use App\Application\Habits\HabitRepository;
use App\Application\Periods\PeriodCloser;
use App\Application\Rewards\FreezeWallet;
use App\Domain\Calendar\LocalDate;
use App\Domain\Clock;
use App\Domain\Habit\DefinitionVersion;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\LogState;
use App\Domain\Insights\Consistency;
use App\Domain\Insights\ConsistencyCalculator;
use App\Domain\Period\PeriodEngine;
use App\Domain\Period\PeriodEvaluation;
use App\Domain\Period\PeriodKind;
use App\Domain\Period\PeriodStatus;
use App\Domain\Reward\XpEntitlementState;
use App\Domain\Reward\XpRules;
use Illuminate\Support\Facades\DB;
use stdClass;

/**
 * GET /insights (A47, spec 06; design 14 and 15). The window is the user's local week or month
 * containing their local today at request time (UserCalendar), never a client date. Periods
 * come from the same PeriodEngine the closer stores from, with the habit's active freeze
 * usages; a closed period takes its status from its stored evaluation, as the heatmap does.
 * Every count and percentage comes from ConsistencyCalculator; xp_earned from the XP entitlements. Read-only, owner-scoped.
 */
final readonly class InsightsQuery
{
    public const array PERIODS = ['week', 'month'];

    public function __construct(
        private HabitRepository $habits,
        private HabitTypeRegistry $types,
        private PeriodCloser $closer,
        private FreezeWallet $wallet,
        private ConsistencyCalculator $calculator,
        private Clock $clock,
    ) {}

    /** @return array<string, mixed> */
    public function build(string $userId, string $period, ?string $category): array
    {
        $this->closer->closeUserIfStale($userId);
        $timeline = UserCalendar::timeline($userId);
        $today = $timeline->localDateAt($this->clock->now());
        [$start, $end] = self::window($period, $today);
        $yesterday = $today->addDays(-1);

        $engine = new PeriodEngine($this->types);
        $all = [];
        $byCategory = [];
        $openPeriods = [];
        $due = [];
        $completed = [];
        // A34: archived routines are excluded (design 14's note).
        $habits = DB::table('habits')->where('user_id', $userId)->whereNull('archived_at')->whereNull('deleted_at')->orderBy('id')->get();
        foreach ($habits as $habit) {
            $type = $this->types->get((string) $habit->type);
            $logs = [];
            $rows = DB::table('habit_logs')->where('habit_id', $habit->id)->whereNull('deleted_at')
                ->whereBetween('log_date', [$start->addDays(-6)->toString(), $end->toString()])
                ->get(['log_date', 'value', 'detail']);
            foreach ($rows as $log) {
                $logs[(string) $log->log_date] = new LogState($type->fromStorage((string) $log->value), HabitRepository::json($log->detail));
            }
            $periods = $engine->periods($this->habits->schedule($habit), $start, $end, $timeline);
            $stored = DB::table('period_evaluations')->where('habit_id', $habit->id)
                ->whereBetween('start_date', [$start->addDays(-6)->toString(), $end->toString()])
                ->get(['period_key', 'completed', 'protected'])->keyBy('period_key');

            foreach ($engine->evaluate($periods, $logs, $today, $this->wallet->activeKeys((string) $habit->id)) as $evaluation) {
                $evaluation = self::withStoredStatus($evaluation, $stored->get($evaluation->period->key));
                $definition = $evaluation->period->definition;
                if ($category !== null && $definition->category !== $category) {
                    continue;
                }
                $all[] = $evaluation;
                $byCategory[$definition->category][] = $evaluation;

                if ($period !== 'week') {
                    continue;
                }
                $date = $evaluation->period->startDate;
                if ($evaluation->period->kind === PeriodKind::Day && ! $date->isAfter($today)) {
                    $key = $date->toString();
                    $due[$key] = ($due[$key] ?? 0) + 1;
                    $completed[$key] = ($completed[$key] ?? 0) + ($evaluation->status === PeriodStatus::Complete ? 1 : 0);
                }
                if ($evaluation->period->kind === PeriodKind::Week && ! $evaluation->closed && $evaluation->current) {
                    $openPeriods[] = [
                        'habit_id' => (string) $habit->id,
                        'completed' => $evaluation->completedDays,
                        'target' => $definition->frequency->count,
                    ];
                }
            }
        }

        $data = [
            'period' => $period,
            'category' => $category,
            'window' => [
                'start' => $start->toString(),
                'end' => $end->toString(),
                'today' => $today->toString(),
                // The last closed local date, while it is inside the window.
                'through' => $yesterday->isBefore($start) ? null : $yesterday->toString(),
            ],
            'totals' => self::consistency($this->calculator->summarize($all, $start, $end)),
            'xp_earned' => $yesterday->isBefore($start) ? 0 : $this->ledgerXp($userId, $start, $yesterday, $category),
            'by_category' => $this->categories($byCategory, $start, $end),
        ];
        if ($period === 'week') {
            $data['days'] = [];
            for ($date = $start; ! $date->isAfter($end); $date = $date->addDays(1)) {
                $future = $date->isAfter($today);
                $data['days'][] = [
                    'date' => $date->toString(),
                    'completed' => $future ? null : $completed[$date->toString()] ?? 0,
                    'due' => $future ? null : $due[$date->toString()] ?? 0,
                    'open' => $date->toString() === $today->toString(),
                ];
            }
            $data['open_periods'] = $openPeriods;
        }

        return $data;
    }

    /**
     * 5.3a review L1: the XP actually given for the window's days through yesterday: one
     * XpRules::XP_PER_COMPLETION per active entitlement (the net ledger, A40), so not-due
     * check-ins and the days of a still-open weekly period count. Archived habits keep theirs.
     * With a category, only habit-days whose definition in force has that category.
     */
    private function ledgerXp(string $userId, LocalDate $from, LocalDate $through, ?string $category): int
    {
        $rows = DB::table('xp_entitlements')->where('user_id', $userId)->where('state', XpEntitlementState::Active->value)
            ->whereBetween('log_date', [$from->toString(), $through->toString()])
            ->get(['habit_id', 'log_date']);
        if ($category !== null) {
            $schedules = [];
            $rows = $rows->filter(function ($row) use (&$schedules, $category) {
                $id = (string) $row->habit_id;
                if (! array_key_exists($id, $schedules)) {
                    $habit = DB::table('habits')->where('id', $id)->first();
                    // A51: a deleted habit has no definitions, so it joins no category; its XP
                    // still counts in the totals.
                    $schedules[$id] = $habit === null || $habit->deleted_at !== null ? null : $this->habits->schedule($habit);
                }
                $schedule = $schedules[$id];
                if ($schedule === null) {
                    return false;
                }
                $date = LocalDate::fromString((string) $row->log_date);

                return ($schedule->versionOn($date) ?? $schedule->latest())->category === $category;
            });
        }

        return $rows->count() * XpRules::XP_PER_COMPLETION;
    }

    /** @return array{LocalDate, LocalDate} */
    private static function window(string $period, LocalDate $today): array
    {
        if ($period === 'week') {
            $monday = $today->mondayOfWeek();

            return [$monday, $monday->addDays(6)];
        }
        $first = LocalDate::fromString(substr($today->toString(), 0, 8).'01');
        // Day 1 plus 31 days always falls in the next month.
        $next = LocalDate::fromString(substr($first->addDays(31)->toString(), 0, 8).'01');

        return [$first, $next->addDays(-1)];
    }

    /**
     * A closed period reads as its stored evaluation says (completed, protected or missed).
     */
    private static function withStoredStatus(PeriodEvaluation $evaluation, ?stdClass $row): PeriodEvaluation
    {
        if (! $evaluation->closed || $row === null) {
            return $evaluation;
        }
        $status = match (true) {
            (bool) $row->completed => PeriodStatus::Complete,
            (bool) $row->protected => PeriodStatus::Protected,
            default => PeriodStatus::Missed,
        };

        return new PeriodEvaluation($evaluation->period, $status, true, $evaluation->current, $evaluation->completedDays);
    }

    /**
     * @param  array<string, list<PeriodEvaluation>>  $byCategory
     * @return list<array<string, mixed>>
     */
    private function categories(array $byCategory, LocalDate $start, LocalDate $end): array
    {
        $rows = [];
        $summaries = $this->calculator->byCategory($byCategory, $start, $end);
        foreach (DefinitionVersion::CATEGORIES as $category) {
            $c = $summaries[$category] ?? null;
            if ($c !== null && $c->eligible > 0) {
                $rows[] = ['category' => $category, ...self::consistency($c)];
            }
        }

        return $rows;
    }

    /** @return array{completed: int, eligible: int, percent: ?int} */
    private static function consistency(Consistency $c): array
    {
        return ['completed' => $c->completed, 'eligible' => $c->eligible, 'percent' => $c->percent];
    }
}
