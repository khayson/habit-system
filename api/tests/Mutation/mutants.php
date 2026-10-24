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
    [
        'name' => 'A33: register does not store the accepted versions',
        'file' => 'app/Application/Accounts/AccountService.php',
        'search' => <<<'PHP'
                'terms_version' => $termsVersion,
                'privacy_version' => $privacyVersion,
PHP,
        'replace' => '',
        'tests' => 'tests/Feature/LegalConsentTest.php',
    ],
    [
        'name' => '3b: profile.update skips the owner check',
        'file' => 'app/Application/Mutations/Handlers/ProfileUpdate.php',
        'search' => 'if ($m->entityId !== strtolower($ctx->userId)) {',
        'replace' => 'if (false) {',
        'tests' => 'tests/Feature/ProfileUpdateTest.php',
    ],
    [
        'name' => '3b: profile.update ignores a stale base version',
        'file' => 'app/Application/Mutations/Handlers/ProfileUpdate.php',
        'search' => 'if ($m->baseVersion !== $version) {',
        'replace' => 'if (false) {',
        'tests' => 'tests/Feature/ProfileUpdateTest.php',
    ],
    [
        'name' => '3b: the pixel cap refuses a photo exactly at 25 MP',
        'file' => 'app/Domain/Avatar/AvatarPipeline.php',
        'search' => 'if ($width * $height > self::MAX_PIXELS) {',
        'replace' => 'if ($width * $height >= self::MAX_PIXELS) {',
        'tests' => 'tests/Unit/Avatar/AvatarPipelineTest.php',
    ],
    [
        'name' => '3b: the size cap lets 10 MB through',
        'file' => 'app/Domain/Avatar/AvatarPipeline.php',
        'search' => 'if (strlen($bytes) > self::MAX_BYTES) {',
        'replace' => 'if (strlen($bytes) > self::MAX_BYTES * 2) {',
        'tests' => 'tests/Unit/Avatar/AvatarPipelineTest.php',
    ],
    [
        'name' => '3b: the store accepts any avatars/ key',
        'file' => 'app/Application/Avatars/AvatarStore.php',
        'search' => "return preg_match('#^'.\$prefix.self::UUID.'-lg\.(webp|jpg)\$#', \$lgKey) === 1;",
        'replace' => "return str_starts_with(\$lgKey, 'avatars/');",
        'tests' => 'tests/Feature/AvatarStoreTest.php tests/Feature/AvatarEndpointTest.php',
    ],
    [
        'name' => '3b: eleven avatar uploads an hour',
        'file' => 'config/api.php',
        'search' => "env('RATE_LIMIT_AVATAR_UPLOADS_PER_HOUR', 10)",
        'replace' => "env('RATE_LIMIT_AVATAR_UPLOADS_PER_HOUR', 11)",
        'tests' => 'tests/Feature/AvatarEndpointTest.php',
    ],
    [
        'name' => '3b: EXIF orientation is not applied',
        'file' => 'app/Domain/Avatar/AvatarPipeline.php',
        'search' => '$image = self::orient($image, $orientation);',
        'replace' => '',
        'tests' => 'tests/Unit/Avatar/AvatarPipelineTest.php',
    ],
    [
        'name' => '4.1: an increment is applied as a set',
        'file' => 'app/Application/Mutations/Handlers/LogIncrement.php',
        'search' => "\$next = \$type->apply('log.increment', \$current, \$p['delta'], \$definition);",
        'replace' => "\$next = \$type->apply('log.set_value', \$current, \$p['delta'], \$definition);",
        'tests' => 'tests/Feature/HabitMutationsTest.php',
    ],
    [
        'name' => '4.1: a definition change takes effect today',
        'file' => 'app/Application/Mutations/Handlers/HabitWrites.php',
        'search' => "'effective_date' => HabitSchedule::nextEffectiveDate(\$today, \$latest->frequency, \$frequency)->toString(),",
        'replace' => "'effective_date' => \$today->toString(),",
        'tests' => 'tests/Feature/HabitMutationsTest.php',
    ],
    [
        'name' => '4.1: a pending version is appended instead of replaced',
        'file' => 'app/Application/Mutations/Handlers/HabitWrites.php',
        'search' => '} elseif ($pending) {',
        'replace' => '} elseif (false) {',
        'tests' => 'tests/Feature/HabitMutationsTest.php',
    ],
    [
        'name' => '4.1: archive ends the range a day late',
        'file' => 'app/Application/Mutations/Handlers/HabitWrites.php',
        'search' => '$tomorrow = $this->today($ctx)->addDays(1);',
        'replace' => '$tomorrow = $this->today($ctx)->addDays(2);',
        'tests' => 'tests/Feature/HabitMutationsTest.php',
    ],
    [
        'name' => '4.1: habit writes skip the version check',
        'file' => 'app/Application/Mutations/Handlers/HabitWrites.php',
        'search' => 'if ($m->baseVersion !== (int) $habit->version) {',
        'replace' => 'if (false) {',
        'tests' => 'tests/Feature/HabitMutationsTest.php',
    ],
    [
        'name' => '4.1: a log write lands on an archived habit',
        'file' => 'app/Application/Mutations/MutationApplier.php',
        'search' => "if (\$habit->archived_at !== null) {\n                throw new HabitArchived((string) \$habit->id);",
        'replace' => "if (false) {\n                throw new HabitArchived((string) \$habit->id);",
        'tests' => 'tests/Feature/HabitMutationsTest.php',
    ],
    [
        'name' => '4.1: an interval change starts on its current period',
        'file' => 'app/Domain/Habit/HabitSchedule.php',
        'search' => '$periods = intdiv($old->anchorDate->daysUntil($today), $old->everyNDays) + 1;',
        'replace' => '$periods = intdiv($old->anchorDate->daysUntil($today), $old->everyNDays);',
        'tests' => 'tests/Unit/Domain/NextEffectiveDateTest.php',
    ],
    // Phase 5.1 ---------------------------------------------------------------------------
    [
        'name' => '5.1: an edit that stays complete earns XP again',
        'file' => 'app/Application/Rewards/XpAwarder.php',
        'search' => 'if ($wasComplete === $isComplete) {',
        'replace' => 'if (false) {',
        'tests' => 'tests/Feature/XpTest.php',
    ],
    [
        'name' => '5.1: reward_version does not rise with a reward change',
        'file' => 'app/Application/Rewards/RewardState.php',
        'search' => 'reward_version = reward_version + 1',
        'replace' => 'reward_version = reward_version',
        'tests' => 'tests/Feature/RewardEntitiesTest.php',
    ],
    [
        'name' => '5.1: a spend leaves the cached balance alone',
        'file' => 'app/Application/Rewards/FreezeWallet.php',
        'search' => '$this->rewards->apply($userId, 0, -count($closure->usages));',
        'replace' => '$this->rewards->apply($userId, 0, 0);',
        'tests' => 'tests/Feature/FreezeTest.php',
    ],
    [
        'name' => '5.1: the wallet re-offers periods that closed before its watermark',
        'file' => 'app/Application/Periods/PeriodCloser.php',
        'search' => '($since === null || $evaluation->period->endDate->isAfter($since))',
        'replace' => 'true',
        'tests' => 'tests/Feature/FreezeTest.php',
    ],
    [
        'name' => '5.1: a protected period completed late is not refunded',
        'file' => 'app/Application/Periods/PeriodCloser.php',
        'search' => '$evaluation->status === PeriodStatus::Complete && in_array($evaluation->period->key, $active, true)',
        'replace' => 'false',
        'tests' => 'tests/Feature/FreezeTest.php',
    ],
    [
        'name' => '5.1: an identical auto-freeze setting writes a policy version',
        'file' => 'app/Application/Mutations/Handlers/ProfileSetAutoFreeze.php',
        'search' => 'if ($enabled === (bool) $user->auto_freeze) {',
        'replace' => 'if (false) {',
        'tests' => 'tests/Feature/RewardEntitiesTest.php',
    ],
    [
        'name' => '5.1: a ledger page repeats the row its cursor points at',
        'file' => 'app/Application/Rewards/RewardsQuery.php',
        'search' => "'(l.created_at, l.id) < (?::timestamptz, ?::uuid)'",
        'replace' => "'(l.created_at, l.id) <= (?::timestamptz, ?::uuid)'",
        'tests' => 'tests/Feature/RewardEndpointsTest.php',
    ],
    [
        'name' => '5.1: the heatmap misses a week that starts before its window',
        'file' => 'app/Application/Periods/HeatmapService.php',
        'search' => "->whereBetween('start_date', [\$from->addDays(-6)->toString(), \$to->toString()])",
        'replace' => "->whereBetween('start_date', [\$from->toString(), \$to->toString()])",
        'tests' => 'tests/Feature/HeatmapTest.php',
    ],
    // Phase 5.2a --------------------------------------------------------------------------
    [
        'name' => '5.2a: an accepted ack drops xp_delta (A43)',
        'file' => 'app/Application/Mutations/MutationApplier.php',
        'search' => ', xpDelta: $result->xpDelta);',
        'replace' => ');',
        'tests' => 'tests/Feature/AckXpDeltaTest.php',
    ],
    // Phase 5.3a --------------------------------------------------------------------------
    [
        'name' => '5.3a: a protected period counts as completed',
        'file' => 'app/Domain/Insights/ConsistencyCalculator.php',
        'search' => 'if ($evaluation->status === PeriodStatus::Complete) {',
        'replace' => 'if ($evaluation->status !== PeriodStatus::Missed) {',
        'tests' => 'tests/Feature/InsightsEndpointTest.php',
    ],
    [
        'name' => '5.3b: xp_earned counts today (the through bound dropped)',
        'file' => 'app/Application/Insights/InsightsQuery.php',
        'search' => "->whereBetween('log_date', [\$from->toString(), \$through->toString()])",
        'replace' => "->whereBetween('log_date', [\$from->toString(), \$through->addDays(1)->toString()])",
        'tests' => 'tests/Feature/InsightsEndpointTest.php',
    ],
    [
        'name' => '5.3a: an open period enters the window',
        'file' => 'app/Domain/Insights/ConsistencyCalculator.php',
        'search' => "if (! \$evaluation->closed\n                || ",
        'replace' => "if (false\n                || ",
        'tests' => 'tests/Feature/InsightsEndpointTest.php',
    ],
    [
        'name' => '5.3a: an archived habit is counted',
        'file' => 'app/Application/Insights/InsightsQuery.php',
        'search' => "->whereNull('archived_at')->orderBy('id')",
        'replace' => "->orderBy('id')",
        'tests' => 'tests/Feature/InsightsEndpointTest.php',
    ],
    [
        'name' => '5.3a: percentages round down instead of half up',
        'file' => 'app/Domain/Insights/ConsistencyCalculator.php',
        'search' => 'intdiv(200 * $completed + $eligible, 2 * $eligible)',
        'replace' => 'intdiv(200 * $completed, 2 * $eligible)',
        'tests' => 'tests/Feature/InsightsEndpointTest.php',
    ],
    [
        'name' => '5.3a: by_category drops a category, so it no longer sums to the totals',
        'file' => 'app/Application/Insights/InsightsQuery.php',
        'search' => 'foreach (DefinitionVersion::CATEGORIES as $category) {',
        'replace' => 'foreach (array_slice(DefinitionVersion::CATEGORIES, 0, 3) as $category) {',
        'tests' => 'tests/Feature/InsightsEndpointTest.php',
    ],
    // Phase 6.1 ---------------------------------------------------------------------------
    [
        'name' => '6.1: the download skips the owner check',
        'file' => 'app/Http/Controllers/Api/V1/ExportController.php',
        'search' => "->where('id', strtolower(\$export))->where('user_id', \$user->id)->first()",
        'replace' => "->where('id', strtolower(\$export))->first()",
        'tests' => 'tests/Feature/ExportEndpointsTest.php',
    ],
    [
        'name' => '6.1: an expired link still downloads',
        'file' => 'app/Http/Controllers/Api/V1/ExportController.php',
        'search' => "if (\$job->status === 'expired' || (\$job->status === 'ready' && \$this->expired(\$job))) {",
        'replace' => 'if (false) {',
        'tests' => 'tests/Feature/ExportEndpointsTest.php',
    ],
    [
        'name' => '6.1: CSV cells are not neutralised',
        'file' => 'app/Domain/Export/CsvWriter.php',
        'search' => "return \$cell !== '' && in_array(\$cell[0], self::FORMULA_STARTS, true) ? \"'\".\$cell : \$cell;",
        'replace' => 'return $cell;',
        'tests' => 'tests/Unit/Domain/ExportFormatTest.php tests/Feature/ExportEndpointsTest.php',
    ],
    [
        'name' => '6.1: the manifest signature no longer binds user_id',
        'file' => 'app/Domain/Export/ManifestSigner.php',
        'search' => "        unset(\$manifest['signature']);\n        \$expected = hash_hmac('sha256', CanonicalJson::encode(\$manifest), \$this->keys[\$kid]);",
        'replace' => "        unset(\$manifest['signature'], \$manifest['user_id']);\n        \$expected = hash_hmac('sha256', CanonicalJson::encode(\$manifest), \$this->keys[\$kid]);",
        'tests' => 'tests/Unit/Domain/ExportFormatTest.php',
    ],
    [
        'name' => '6.1: the export carries the password hash',
        'file' => 'app/Application/Exports/ExportBuilder.php',
        'search' => "'name' => \$user->name, 'email' => \$user->email,",
        'replace' => "'name' => \$user->name, 'email' => \$user->email, 'password' => \$user->password,",
        'tests' => 'tests/Feature/ExportEndpointsTest.php',
    ],
];
