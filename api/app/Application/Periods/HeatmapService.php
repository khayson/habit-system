<?php

namespace App\Application\Periods;

use App\Application\Calendar\UserCalendar;
use App\Application\Habits\HabitRepository;
use App\Domain\Calendar\LocalDate;
use App\Domain\Clock;
use App\Domain\Habit\HabitTypeRegistry;
use App\Domain\Habit\LogState;
use App\Domain\Period\PeriodEngine;
use App\Domain\Period\PeriodKind;
use App\Domain\Period\PeriodStatus;
use Illuminate\Support\Facades\DB;
use stdClass;

/**
 * GET /habits/{id}/heatmap (spec 06): one status per local date in a window of at most 366 days.
 * Closed daily periods come from period_evaluations (the closer runs first, A10); open and future
 * periods come from the engine. Dates that are not part of the grid are not_due: unscheduled,
 * inactive, before the start, or zero-length (A30). Every status has a text label (invariant 12).
 */
final readonly class HeatmapService
{
    public const int MAX_DAYS = 366;

    /** The design file's legend words (screen 12); pending is the open status. */
    public const array LEGEND = [
        ['status' => 'complete', 'label' => 'Complete'],
        ['status' => 'protected', 'label' => 'Protected'],
        ['status' => 'missed', 'label' => 'Missed'],
        ['status' => 'not_due', 'label' => 'Not due'],
        ['status' => 'pending', 'label' => 'Pending'],
    ];

    public function __construct(
        private HabitRepository $habits,
        private HabitTypeRegistry $types,
        private PeriodCloser $closer,
        private Clock $clock,
    ) {}

    /** @return array<string, mixed> */
    public function build(string $userId, stdClass $habit, LocalDate $from, LocalDate $to): array
    {
        $this->closer->closeUserIfStale($userId);
        $timeline = UserCalendar::timeline($userId);
        $today = $timeline->localDateAt($this->clock->now());
        $type = $this->types->get((string) $habit->type);

        $logs = [];
        $rows = DB::table('habit_logs')->where('habit_id', $habit->id)->whereNull('deleted_at')
            ->whereBetween('log_date', [$from->addDays(-6)->toString(), $to->addDays(6)->toString()])
            ->get(['log_date', 'value', 'detail']);
        foreach ($rows as $log) {
            $logs[(string) $log->log_date] = new LogState($type->fromStorage((string) $log->value), HabitRepository::json($log->detail));
        }
        $engine = new PeriodEngine($this->types);
        $evaluations = $engine->evaluate($engine->periods($this->habits->schedule($habit), $from, $to, $timeline), $logs, $today);

        $stored = DB::table('period_evaluations')->where('habit_id', $habit->id)
            ->whereBetween('start_date', [$from->toString(), $to->toString()])
            ->get(['period_key', 'completed', 'protected'])->keyBy('period_key');

        $status = [];
        foreach ($evaluations as $evaluation) {
            $period = $evaluation->period;
            $row = $stored->get($period->key);
            $value = match (true) {
                $evaluation->closed && $period->kind === PeriodKind::Day && $row !== null => match (true) {
                    (bool) $row->completed => 'complete',
                    (bool) $row->protected => 'protected',
                    default => 'missed',
                },
                default => match ($evaluation->status) {
                    PeriodStatus::Complete => 'complete',
                    PeriodStatus::Protected => 'protected',
                    PeriodStatus::Missed => 'missed',
                    PeriodStatus::Pending => 'pending',
                },
            };
            foreach ($period->activeDates as $date) {
                $status[$date->toString()] = $value;
            }
        }

        $days = [];
        for ($date = $from; ! $date->isAfter($to); $date = $date->addDays(1)) {
            $days[] = ['date' => $date->toString(), 'status' => $status[$date->toString()] ?? 'not_due'];
        }

        return [
            'habit_id' => $habit->id,
            'from' => $from->toString(),
            'to' => $to->toString(),
            'today' => $today->toString(),
            'days' => $days,
            'legend' => self::LEGEND,
        ];
    }
}
