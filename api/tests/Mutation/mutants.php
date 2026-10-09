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
        'search' => '$revision = (int) $existing->revision + 1;',
        'replace' => '$revision = (int) $existing->revision;',
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
        'search' => '$candidate = $current->dayStartAfter($now, $k);',
        'replace' => '$candidate = $now;',
    ],
    [
        'name' => 'A30: zero-length dates count as missed days',
        'file' => 'app/Domain/Period/PeriodEngine.php',
        'search' => '! $schedule->isActive($date) || ! $exists($date)',
        'replace' => '! $schedule->isActive($date)',
    ],
    [
        'name' => 'H2: the closer reads each closed day with its own query',
        'file' => 'app/Application/Periods/PeriodCloser.php',
        'search' => '$stored[$evaluation->period->key] ?? null',
        'replace' => "DB::table('period_evaluations')->where('habit_id', \$habit->id)->where('period_key', \$evaluation->period->key)->first()",
        'tests' => 'tests/Feature/PeriodCloserTest.php',
    ],
    [
        // H1: the pre-3.2 rule (newest entry whose own day start is after its effective_at).
        'name' => 'H1: a date starts at the newest entry\'s own day start',
        'file' => 'app/Domain/Calendar/TimezoneTimeline.php',
        'search' => <<<'PHP'
        for ($i = 0; $i < $n; $i++) {
            $start = self::startFor($date, $this->entries[$i]);
            if ($i > 0 && $start < $this->entries[$i]->effectiveAt) {
                $start = $this->entries[$i]->effectiveAt;
            }
            if ($i === $n - 1 || $start < $this->entries[$i + 1]->effectiveAt) {
                return $start;
            }
        }
PHP,
        'replace' => <<<'PHP'
        foreach (array_reverse($this->entries) as $entry) {
            $start = self::startFor($date, $entry);
            if ($entry->effectiveAt <= $start) {
                return $start;
            }
        }

        return self::startFor($date, $this->entries[0]);
PHP,
    ],
    [
        'name' => '3.2b: reminder update reads the row without the owner scope',
        'file' => 'app/Application/Mutations/Handlers/ReminderWrites.php',
        'search' => "\$row = DB::table('reminders')->where('id', \$m->entityId)->where('user_id', \$ctx->userId)->lockForUpdate()->first()",
        'replace' => "\$row = DB::table('reminders')->where('id', \$m->entityId)->lockForUpdate()->first()",
        'tests' => 'tests/Feature/ReminderTest.php',
    ],
    [
        'name' => '3.2b: a reminder delete is not journaled',
        'file' => 'app/Application/Mutations/Handlers/ReminderWrites.php',
        'search' => "return \$this->journaled(\$ctx->userId, \$m->entityId, 'delete');",
        'replace' => "return new HandlerResult('reminder', \$m->entityId, (int) \$row->version + 1);",
        'tests' => 'tests/Feature/ReminderTest.php',
    ],
    [
        'name' => '3.2c: reminder.create without the foreign-id check',
        'file' => 'app/Application/Mutations/Handlers/ReminderWrites.php',
        'search' => <<<'PHP'
            if ($existing->user_id !== $ctx->userId) {
                throw new ApiException(404, 'not_found', 'Not found.');
            }
PHP,
        'replace' => '',
        'tests' => 'tests/Feature/ReminderTest.php',
    ],
    [
        'name' => '3.2c: the bootstrap reads reminders without the owner scope',
        'file' => 'app/Application/Sync/BootstrapService.php',
        'search' => "\$rows = DB::table('reminders')->where('user_id', \$userId)",
        'replace' => "\$rows = DB::table('reminders')",
        'tests' => 'tests/Feature/ReminderTest.php',
    ],
];
