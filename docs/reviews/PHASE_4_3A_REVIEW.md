# Phase 4.3a review (the logging data layer: increments, timer drafts, conflict resolution; the 4.2b carry-overs)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-11
Scope: `927d6cc..af5b33e` (16 commits, 39 files; nothing under `api/` or `contract-fixtures/`). Read at code level: `log_overlay.dart` and `conflicts.dart` in full; the diffs of `local_mutation_service.dart` (increments, timers, conflicts), `local_view.dart`, `sync_engine.dart`, `app_database.dart`, `provisional_type_rules.dart`, `habit_draft.dart`, `edit_habit_screen.dart`, `habit_form.dart`, `SPEC_AMENDMENTS.md`, `BUILD_PLAN.md`, the migration test and the new e2e scenarios plus the sync helper; `conflict_resolution_test.dart` lines 20 to 220 and about half of `log_increment_test.dart`; the names of every new data test. I also read the engine's push selection (`_eligible`) and the API's `resourceDeleted` call sites to check two claims. I did not read the bodies of the timer tests, the screen tests for the carry-overs, the fake-server diff or the generated drift file. I did not run any check and did not open the per-job CI results.

## 1. Verdict

**Phase 4.3a is accepted.** The shared apply step is real (every reader goes through `LocalView.log`, and a test makes four readers agree on one sequence), increments never get a base version, the timer is a small, honest state machine with one transaction at the end, and the conflict plan is decided once for the read model and the writer. One Medium finding and two Low findings ride along in 4.3b's Part 0; three Info items follow. Nothing blocks 4.3b.

## 2. What I verified

| Check | Result |
|---|---|
| `af5b33e` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `af5b33e53686718623fbd94f39a2349201584a55` |
| CI run 38156718416 | Success on `af5b33e`, push, 2m44s: api 1m39s, docker-compose 4s, app 2m41s, e2e 2m23s. The page shows only the overall result. The e2e job grew from 1m26s (see L1) |
| Test counts | Pest 585 (unchanged; no `api/` file in the diff, so skipping mutation-check is right), Flutter 551 to 596, e2e 17 to 21 scenarios. From the packet |
| 4.2b carry-overs | L1 `HabitDraft.merged` per field, with the form's start draft; L2 `inForceToday` null; I1 range fixed from the opening anchor; I2 `HabitFormErrors.fromProblems` on both screens; I3 a 4 + 3 grid; I4 label, key and tags. Each has a failing-first line in the packet. L3 is only half done (see L2 below) |
| `incrementLog` | Validates through the type's own rule on the day as this device shows it; `base_version` is null; folds only into a PENDING increment on the same habit-day, with the type's rule and never into an in-flight row or across kinds; on a day that shows deleted it writes a `log.set_value` restore on the tombstone's version |
| Engine | `_rebase` skips `log.increment`; rows behind an unacked increment still send in order (the test sends increment, set_value on base 2, increment, with null, 2, null) |
| Shared apply step | `applyLogRows` is the only code that applies queued log rows. A grep of `lib/` for `log.set_value`, `log.delete` and `log.increment` finds no other reader that decodes queued payloads; the planner, Today, the week, history and the heatmap all read `LocalView.log`. The test sequence (confirmed 1.000, +0.250, set 3.000, +0.500) shows 3.500 in the log, Today, the detail view and completion |
| Timers | `elapsedAt` never shrinks on a clock set backwards; pause banks, resume restarts, start/pause/resume are idempotent; finish deletes the draft and queues the increment in one transaction, and a refused increment or `tooLong` rolls the deletion back; discard never checks the type |
| Schema v9 | One new table, created for `from < 9`; the upgrade test keeps the outbox row, a scheduled notification and the cursor, and the version assertions are updated |
| Conflicts | `UseMinePlan` is the single decision (new id, the original `occurred_at`, `current.version` as base, the increment-to-restore exception, the archived-habit rule); `ConflictView` reads only what the answer carries; `keepSynced` is the existing discard. One gap: see M1 |
| e2e | `log-increment` (two devices, one folded row, sum 750.500 on both and the server), `log-conflict` (keep synced converges; use mine converges on the higher version), `log-deleted` (kept with the tombstone as `current`; use mine restores with B's amount), `timer-draft` (60.5 s + 60 s is 120 whole seconds; both devices agree) |
| Docs | A36 and A37 are in `SPEC_AMENDMENTS.md` after A35, with the text I gave; BUILD_PLAN splits 4.3 |

## 3. Findings

**M1 · Medium · "Use mine" puts the new row at the back of the queue, behind changes the person made after it**
`useMine` deletes the old row (through `discard`) and inserts a new one without a `seq`, so it gets the highest sequence number. But the engine holds every later row of the same habit-day behind a `needs_attention` row (`_eligible`), so rows the person added while the conflict waited are still there with lower numbers. Sequence: the server holds 1.75 (version 9); a stale `set_value` of 1.50 is in `needs_attention`; the person adds +0.25, which queues behind it and is held. The overlay applies both in order and shows 1.75 (1.50 + 0.25). On screen 19 they choose "Use my value". The new row is now last, so the overlay shows 1.50 (the increment first, on the server's 1.75, then the set_value). On sync the increment goes first and the server moves to 2.00 (version 10); the engine then rebases the set_value onto that ack (F4), so it is accepted without a second review and the server ends at 1.50. The +0.25 is gone, without a message, and the number on screen jumped while they watched. The A37 text I wrote said "a NEW mutation is queued" and never said where; that gap is mine.
Fix: insert the new row with the old row's `seq` (the old row is already deleted in the same transaction, so the number is free), so the order the person made the changes in is kept. Add to A37: "the new mutation keeps the old row's place in the queue." Tests: a stale set_value in `needs_attention` with an increment queued behind it; use mine; the send order is set_value then increment; the server ends at mine plus the increment and the overlay's value does not change when the choice is made. Also with keep synced: the held increment applies to the server's value.

**L1 · Low · The e2e job waits out the API's rate limit instead of raising it**
One account shares the API's 60 syncs a minute across all scenarios, so the sync helper now waits up to 30 seconds after a 429. The CI e2e job went from 1m26s to 2m23s. The limit is a setting (`RATE_LIMIT_SYNC_PER_MINUTE`, default 60, in `config/api.php`).
Fix: set `RATE_LIMIT_SYNC_PER_MINUTE=600` for the API process in the e2e CI job and in the local e2e script; keep the retry as a safety net. List the file in the packet as a deviation.

**L2 · Low · L3 (day-first dates) reaches only some screens**
`dayMonth` is day-first now, but other formats still print month-first: `fullDate` ("May 25, 2026"; History and the detail cells), the Today header (`yMMMMEEEEd`, "Thursday, May 28, 2026" where the design prints "Thursday, 28 May 2026"), the queue's timestamps (`MMMd` plus time), the reminder editor (`MMMEd`) and the server status screen. Deviation 11 changed the `fullDate` comment to match the output; the output should have been changed to match the design.
Fix: ARB-held patterns beside `dayMonth` (a full date "25 May 2026", a weekday date "Thursday, 28 May 2026", a day-month with time) and use them in all of those places; update the tests that expect month-first text.

**I1 · Info · A timer left running can only be discarded after a day**
A running draft keeps counting while the app is closed (that is the design of A36). One left running for more than 25 hours cannot be finished (`tooLong`) and stays until discarded; the same happens to a running draft on a habit that was archived and restored a month later. 4.3b's timer screen must therefore handle `tooLong` with two ways out: discard the timer, or enter the time by hand (the amount screen, in minutes) and then discard.

**I2 · Info · The sync queue words increments and habit edits as "Other"**
Screen 18 words `habit.create`, `log.set_value`, `log.delete` and the profile changes, and everything else as `queueChangeOther`. An increment (or an edit, archive or restore) that waits there reads as "Other". Belongs to 4.3c with the conflict screen.

**I3 · Info · A37 rule (2) keeps an old base version for habit rows**
For a habit edit refused with `habit_archived`, "use mine" keeps the row's own base version. After the other device's archive and this device's restore the habit's version has moved on, so it would conflict a second time. In practice the server checks the version first, so such a row arrives as `version_conflict` and takes the normal path; the case should not occur. Leave it, and amend A37 only if a device ever shows it.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 Fake server: `log.increment`, an `onMutation` hook | Accepted |
| 2 The e2e sync helper waits out a 429 | Accepted as a safety net; L1 removes the need |
| 3 `/frequency` without its request goes to Today | Accepted (I had said pop first; going to Today is simpler and safe) |
| 4 `_rebase` excludes `log.increment` (a `lib/sync` change) | Accepted; it was required by A35 and has a test |
| 5 `habitTypeOf` shared in `log_overlay.dart` | Accepted |
| 6 `finishTimer` returns `LocalWrite?`; `TimerDraftView` wraps the row | Accepted |
| 7 `LogFailure` has one kind | Accepted (see answers) |
| 8 `serverDeleted` is true for `resource_deleted` even with no `current`; a stale value without `current` is kind `other` | Accepted |
| 9 `useMine` on a row that no longer needs a look is `notAllowed` | Accepted |
| 10 `unknownType` shows under the target field | Accepted |
| 11 The `fullDate` docblock was changed to the format it prints | Not accepted: see L2 |

## 5. Open questions (answered)

1. **Should the API add `current` to a `set_value` refused with `resource_deleted`?** No. A tombstone has no value to show; the documented contract is `entity`, `resource_id` and `current_version`, and `serverDeleted` is enough for screen 19's deleted-day variant ("deleted on another device"). The increment answer carries `current` (A35) and that stays. No API change.
2. **A separate `LogFailure` kind for a yes/no habit refusing an increment?** No. No screen offers an increment on a yes/no habit; add a kind when a screen needs to word it differently.

## 6. Risks to keep in view

- **Real-device behaviour is still unproven.** The device gate (steps 1 to 14, 16 to 26 and 27 to 31) has not been run.
- **Timers count wall time.** A clock moved forward by hand adds time; a timer started at 23:40 and finished at 00:20 files all 40 minutes under the new day (A36 files under the finish moment). Both are the stated design; the timer screen should not promise otherwise.
- **The e2e job is near the per-user sync limit** until L1 lands. The profile widget tests can still hang under heavy parallel load.
- **Needs-attention rows still reach people only through the queue (18)** until screen 19 exists (4.3c).
- **My 4.1 review still carries one wrong sentence** (the engine lines 370 to 371 were inside the bootstrap transaction); the 4.2a review has the correction.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. The legal items are still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. Phase 4.3b (the prompt follows in the reply): M1, L1 and L2 in its Part 0; the amount-entry screen (34) with its Today quick-add, the timer screen in its two states (33 and 36), and the Today cards for quantity and duration. Then 4.3c: the conflict review (19), the queue wording and the device-gate steps for logging.
