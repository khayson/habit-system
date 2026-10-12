# Phase 4.3c review (the conflict review, screen 19; the queue wording and links; the 4.3b carry-overs; the Phase 4 close)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-12
Scope: `08f73d9..d0aec8f` (17 commits, 32 files; nothing under `api/` or `contract-fixtures/`). Read at code level: `conflict_review_screen.dart` and `habit_draft_diff.dart` in full; the diffs of `conflicts.dart`, `local_mutation_service.dart`, `habit_type_ui.dart`, `habit_actions.dart`, `router.dart`, `sync_queue_screen.dart`, `needs_attention.dart`, `edit_habit_screen.dart`, `habit_detail_screen.dart`, `timer_screen.dart`, `amount_entry_screen.dart`, `sync_provider.dart`, `reminder_scheduling.dart`, the ARB strings, `SPEC_AMENDMENTS.md`, `BUILD_PLAN.md` and `DEVICE_GATE.md`; the new data tests (L1, A2, L2, I2, I3) and, of `conflict_review_screen_test.dart`, its harness, the stale-value test, the kind-other test, the queue tests and the list of names. I did not read the bodies of the other screen 19 tests, `habit_draft_diff_test.dart` or the generated l10n files, I did not look at the screenshots (they are on your machine), and I did not run any check. The CI page shows an overall result and job durations, not per-job results.

## 1. Verdict

**Phase 4.3c is accepted, and Phase 4 is built.** The 4.3b findings are all closed with failing-first evidence, the conflict review reads from the same plan the writer uses (so a button can never offer what `useMine` would refuse), every variant keeps the safe choice as the primary button, and the Phase 4 gate rows map to real tests. Three Low findings and one group of Info notes ride along in the next prompt's Part 0. Nothing blocks the next phase.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `d0aec8f4371a63a93907f1f272fb52a04d307064` |
| CI | Run 38217799723 (#39) on `d0aec8f`: success, push, 3m32s: api 1m26s, docker-compose 6s, app 3m28s, e2e 1m6s. Run 38187475031 (#38) on `08f73d9`, the earlier head with the two reminder commits: success, 3m38s. The page shows only the overall result |
| Test counts | From the packet: Pest 585 (unchanged; `git diff --name-only 08f73d9..d0aec8f -- api contract-fixtures` is empty, so skipping mutation-check is right), Flutter 630 to 665 |
| 4.3b M1 (reminder commits) | A38 is in `SPEC_AMENDMENTS.md` with the text I gave; the full check on `08f73d9` gave exit 0 before any change; step 38 is in the gate |
| 4.3b L1 (exception narrowed) | `useMine` now looks for a later `habit.restore` only when the refusal was `habit_archived`. The new test queues an archive behind a stale set_value: the new row keeps the old seq, the order is set_value then archive, and the server ends with the value and the habit archived. A37's last sentence says so |
| 4.3b L2 (timers on an archived habit) | `pauseTimer` passes `allowArchived`; resume stays refused (the test checks both); A36 has the sentence. The pause and resume buttons go through `_guarded`, which shows the archived words in the failure card; 12's Start timer and 34's "Time it instead" show a snackbar |
| 4.3b L3, I1, I2, I3 | The editor line uses `weekdayDayMonthTime`; 12's add button takes `type.amountTitle`; `replanInBackground` prints `error.runtimeType` in debug builds only (the test checks no habit name is in it); the debounced sync has the same guard, and the test closes the database under the engine, the way the packet says `run` throws |
| A1 to A3 | `entryText` (yes / no: Done and Not done, quantity and duration: `amountText`); a `log.delete` refused with `resource_deleted` has no plan (`canUseMine` false, `useMine` returns `notAllowed`); a stale `log.delete` reads without crashing. `HabitActions.useMine` asks for a sync only when it writes |
| A4 `HabitDraftDiff` | Pure Dart, display formatters passed in; compares name, category, target (by parsed value when the rules are known), unit and schedule (through `HabitDraft.sameAs` on blank drafts), in that order |
| Screen 19 | One `_Plan` per conflict decides the variant, the copy, both cards and the buttons. The stale-value copy matches the design string for string (the test asserts each line). The cards are one semantic group each ("On this device: 1.5 L. Edited at 10:22 AM · based on version 1"). Both buttons are asserted at least 52 high. Keep synced and Use mine act at once and leave with a snackbar; a row that vanishes shows its line and a Back button; the watched stream follows the row |
| Variants | Stale value, stale removal, deleted day (with the amount that would come back), both removed (one Done), archived (Restore, then Save my check-in, or Discard asks first), stale habit edit (every differing field, both ways, plus the sentence that differing fields take the chosen values), stale archive or restore, kind other. All words are in the ARB and all follow my copy |
| Links | Queue: Review beside Discard, new wording for increments and habit changes, the `habit_archived` reason; Today's sheet: Review when reviewable; the blocked note opens 19 for exactly one reviewable row, else the queue. Each has a test |
| Phase 4 gate | The three test names exist where the packet says: `IncrementConcurrencyTest.php` ("adds concurrent increments exactly…"), `SyncTest.php` ("stale absolute edit conflicts with the canonical current value…"), `PeriodEngineTest.php` ("counts distinct completed days for weekly targets"). I checked the names and that no API file changed; I did not run them |
| Docs | A36, A37, A38, DEVICE_GATE 38 to 45 with results rows, BUILD_PLAN marks 4.3b and 4.3c done |

## 3. Findings

**L1 · Low · 19 shows the discard-only screen until the habit's detail has loaded**
`_habit()` returns `_detail!.value` without checking `hasValue`, and the detail stream starts after `TimeZones.ready`. For the first frames `detail` is null, and `_Plan.of` treats `c.habitId != null && detail == null` as the kind-other variant: the subtitle becomes the server's reason and the only button is "Discard this change". It is then replaced by the real variant. The tests settle past it. Fix: while the conflict names a habit and the detail model has no value yet, show the empty Scaffold (the pattern 33 and 34 use); keep the kind-other variant for a habit that loaded as null. Test: open the screen, pump one frame without settling, and assert "Discard this change" is not on screen.

**L2 · Low · Review is offered for changes 19 cannot review**
`reviewable(row)` decides by error code alone. By reading the code, a `profile.update`, `profile.set_timezone` or reminder row refused with `version_conflict` (two devices edited the same profile or reminder) passes it (the queue test uses a `not_found` row, so none of these is covered), so the queue shows Review, and 19 opens in its discard-only variant: an extra tap to the button the queue already has. I asked for "a conflict kind that is not other" (deviation 2 changed the rule). The rule can stay a pure function of the row; it just has to be the same function `_conflictOf` uses. Fix: one pure function from the code and the entity to the kind, used by `_conflictOf` and by `reviewable`; Review shows when the kind is not other (the habit this device cannot read may still open 19, as built). Tests: a profile row and a reminder row refused with `version_conflict` show Discard only in the queue, and the blocked note and Today's sheet do not route them to 19.

**L3 · Low · Two screens run their own database queries**
`EditBlockedNote._review` (with a drift import in a screen) and `ConflictReviewScreen._discard` select from the outbox through `account.session.db`, and the first filters rows with `reviewable` in the widget. The rest of the screens read through `LocalView` or a small data class. Move both into `ConflictQueries`: the mutation ids of a habit's reviewable rows, and one row by id. The screens then call them; the existing screen tests cover the behaviour, and the data test checks the habit lookup (one row, two rows, none).

**I1 · Info · Small notes (no change required; fold the cheap ones into Part 0)**
- After "Discard this check-in" (archived variant) and "Discard this change" (kind other), the snackbar says "Kept the synced value." That is wrong for a discarded check-in or a failed profile change. Say "Discarded this change." for those two.
- The primary button's spinner follows `_busy`, so pressing "Use my value" shows the spinner on "Keep synced value". The spinner should be on the button that was pressed.
- In the stale habit variant, when the diff is empty (or the answer carries no habit), both cards show only their title and line. Show "Changed on another device" in the empty card.
- An increment's card says "Edited at 7:03 AM"; "Added at" is truer. Cheap, and ARB only.
- `_restore` has no catch: if `restoreHabit` throws (an unknown habit), it escapes as an uncaught error. Show `reviewGone` and leave.
- A first check-in reads "based on version 0" (answer 1 below).

## 4. Deviations

| # | Verdict |
|---|---|
| 1 `staleHabitEdit` reused for archive or restore (`mineHabit == null`); `ConflictView` gains `serverArchived` and `lastError` | Accepted |
| 2 `reviewable(row)` by error code | Not accepted for non-habit rows: see L2 |
| 3 d0aec8f: an increment's card names the time only (found in a screenshot); the assertion came with the fix, not before it | Accepted. The fix is right (an increment has no base version, A35), but the rule is a test that fails first, even for a screenshot find |
| 4 "based on version 0" on a first check-in | See answer 1 |
| 5 Harness: the blocked-note test unmounts the app before a second sync; the two-row case uses a check-in conflict then a stale habit edit | Accepted. I cannot tell from the packet whether the hang when a sync runs under a mounted 19 is only a fake-async artefact of the widget test; device-gate step 41 is the real check (a sync while 19 is open) |
| 6 Primary button height comes from `PrimaryButton`; a test checks both buttons are at least 52 | Accepted |
| 7 The dev account `screens.43c@example.test` is local only | Accepted |

ASSUMPTION tags (`4.3c-date-line`, `-stale-remove`, `-both-removed`, `-deleted-day`, `-archived-habit`, `-stale-archive`, `-stale-habit`): all accepted; they are the copy I gave you.

## 5. Open questions (answered)

1. **Should a first check-in say something plainer than "based on version 0"?** Yes. When the base version is 0, the edited and removed lines read "Edited at {time} · first entry of the day" and "Removed at {time} · first entry of the day". The version number stays for every other case.
2. **Who owns screen 01 (Welcome)?** Phase 7 (hardening and release), because the app opens on sign-in and nothing before release depends on the Welcome screen. The next prompt adds the line to BUILD_PLAN; the screen is still in scope and gets built.

Unbuilt screens as reported (Phase 5: 06, 14, 15, 16, 17, 35; Phase 6: 21, 25 to 32; Phase 7: 01; 24 is a state of 08): I took the lists from the packet and BUILD_PLAN and did not check each screen on a device.

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 45.** Phase 4 is built but unproven on a phone. Step 41 (a second sync while 19 is open) and steps 34 and 35 (a locked phone, a killed app, with a running timer) are the ones only a phone can answer.
- **The connectivity-regained sync is still unguarded.** `_onConnectivity` calls `sync(force: true)` unawaited, the shape the debounce had. The packet reports it; 4.3b I3 showed the engine can throw, so it gets the same one-line guard in Part 0.
- **A38 stands on your confirmation.** The pop-up reminder channel is written as adopted. If it was not your decision on the phone, say so and I will reverse it.
- **A forgotten timer** (running more than 25 hours) still needs discarding; your call whether it should pause itself.
- **Dev leftovers:** the PHP dev server on port 8001, the emulator signed in to `screens.43c@example.test` with three open conflicts, and the older test accounts. None may reach a commit.
- **My 4.1 review still carries one wrong sentence** (the engine lines 370 to 371 were inside the bootstrap transaction); the 4.2a review has the correction. I can issue a corrected copy if you want it.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone (the longest list so far: 45 steps). Server-only work does not depend on it, so Phase 5.1 can run alongside.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Legal items, still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. Phase 5 (Rewards and freezes) is next, split like Phase 4 and starting with the server (the prompt follows in the reply). Its Part 0 carries L1 to L3, I1, answer 1, the connectivity guard and the BUILD_PLAN line for screen 01.
