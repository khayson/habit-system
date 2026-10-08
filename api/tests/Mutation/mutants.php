<?php

/*
 * Deliberate bugs the domain suite must catch (R5). Each mutant replaces one exact snippet that
 * must occur exactly once in its file. Keep at least eight.
 */

return [
    [
        'name' => '11 XP per completion instead of 10',
        'file' => 'app/Domain/Reward/XpRules.php',
        'search' => 'XP_PER_COMPLETION = 10',
        'replace' => 'XP_PER_COMPLETION = 11',
    ],
    [
        'name' => 'A8: protect the shortest streak first',
        'file' => 'app/Domain/Freeze/FreezeEvaluator.php',
        'search' => '?: $b->streakAtRisk <=> $a->streakAtRisk',
        'replace' => '?: $a->streakAtRisk <=> $b->streakAtRisk',
    ],
    [
        'name' => 'partial weeks are always due',
        'file' => 'app/Domain/Period/PeriodEngine.php',
        'search' => 'count($active) < $definition->frequency->count',
        'replace' => 'false',
    ],
    [
        'name' => 'protected periods break streaks',
        'file' => 'app/Domain/Streak/StreakCalculator.php',
        'search' => '$run = $evaluation->keepsStreak() ? $run + 1 : 0;',
        'replace' => '$run = $evaluation->status === PeriodStatus::Complete ? $run + 1 : 0;',
    ],
    [
        'name' => 'weeks start on Sunday',
        'file' => 'app/Domain/Calendar/LocalDate.php',
        'search' => 'return $this->addDays(1 - $this->isoWeekday());',
        'replace' => 'return $this->addDays(-($this->isoWeekday() % 7));',
    ],
    [
        'name' => 'off by one at the 90-day offline edge',
        'file' => 'app/Domain/Calendar/DayResolver.php',
        'search' => 'if ($occurredAt < $now->sub(',
        'replace' => 'if ($occurredAt <= $now->sub(',
    ],
    [
        'name' => 'off by one at the 5-minute future edge',
        'file' => 'app/Domain/Calendar/DayResolver.php',
        'search' => 'if ($occurredAt > $now->add(',
        'replace' => 'if ($occurredAt >= $now->add(',
    ],
    [
        'name' => 'DST repeated hour resolves to the second occurrence',
        'file' => 'app/Domain/Calendar/TimezoneTimeline.php',
        'search' => "return (new DateTimeImmutable('@'.min(\$candidates)))",
        'replace' => "return (new DateTimeImmutable('@'.max(\$candidates)))",
    ],
    [
        'name' => 'weekly_count counts check-ins instead of distinct days',
        'file' => 'app/Domain/Period/PeriodEngine.php',
        'search' => '$completedDays++;',
        'replace' => '$completedDays += max(1, intdiv($state->value, $period->definition->target));',
    ],
    [
        'name' => 'late-completion refund ignores the cap',
        'file' => 'app/Domain/Freeze/FreezeEvaluator.php',
        'search' => '$delta = min(1, self::CAP - $balance);',
        'replace' => '$delta = 1;',
    ],
    [
        'name' => 'open periods can spend a freeze',
        'file' => 'app/Domain/Freeze/FreezeEvaluator.php',
        'search' => '! $candidate->closed => FreezeOutcome::PeriodOpen,',
        'replace' => 'false => FreezeOutcome::PeriodOpen,',
    ],
    // Phase 3.1 ---------------------------------------------------------------------------
    [
        'name' => 'A1: the closer writes without the user lock',
        'file' => 'app/Application/Periods/PeriodCloser.php',
        'search' => "            \$this->journal->lockUser(\$userId);\n            \$timeline = UserCalendar::timeline(\$userId);",
        'replace' => '            $timeline = UserCalendar::timeline($userId);',
        'tests' => 'tests/Feature/PeriodCloserConcurrencyTest.php',
    ],
    [
        'name' => 'A10: a changed evaluation keeps its revision',
        'file' => 'app/Application/Periods/PeriodCloser.php',
        'search' => "'revision' => (int) \$existing->revision + 1,",
        'replace' => "'revision' => (int) \$existing->revision,",
        'tests' => 'tests/Feature/PeriodCloserTest.php',
    ],
    [
        'name' => 'invariant 6: an evaluation change is not journaled',
        'file' => 'app/Application/Periods/PeriodCloser.php',
        'search' => "\$this->journal->append(\$userId, 'period_evaluation',",
        'replace' => "if (false) \$this->journal->append(\$userId, 'period_evaluation',",
        'tests' => 'tests/Feature/PeriodCloserTest.php',
    ],
    [
        'name' => 'A26: a calendar change takes effect at the request instant',
        'file' => 'app/Domain/Calendar/CalendarHistory.php',
        'search' => '$effectiveAt = $current->nextDayStartAfter($now);',
        'replace' => '$effectiveAt = $now;',
    ],
    [
        'name' => 'A30: zero-length dates count as missed days',
        'file' => 'app/Domain/Period/PeriodEngine.php',
        'search' => '! $schedule->isActive($date) || ! $exists($date)',
        'replace' => '! $schedule->isActive($date)',
    ],
];
