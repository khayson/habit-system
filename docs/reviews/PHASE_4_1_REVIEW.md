# Phase 4.1 review (habit edit, archive and restore, log increments on the server; carry-over fixes from 3b.2)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-10
Scope: `8b1bbc7..666e754` (15 commits). Read at code level: `HabitWrites`, `LogDay` and `LogIncrement` in full; the diffs of `MutationApplier`, `HabitSchedule`, `ApiException`, `DomainErrorMapper` and `LogDelete`; `JpegScrubber` in full; the diffs of `photo_service.dart`, `app_database.dart`, `avatar_sync.dart`, `avatar_transport.dart`, `http_avatar_transport.dart`, `sync_engine.dart`, `profile_screen.dart`, `profile_sheets.dart` and the arb file; the first half of `IncrementConcurrencyTest` and the writer helper; the case names in the three new fixture files; the names of the new Pest tests and the seven new mutants; the Phase 4 text in BUILD_PLAN, A34 and A35, and the step 26 row. Then, to judge what the app must do next: `LocalView`, the library row, `ReminderPlanner` and the scheduling watch, `ProvisionalTypeRegistry`. I did not read the bodies of `HabitMutationsTest`, `HabitOwnershipTest` or `NextEffectiveDateTest`, the fixture bodies, the Flutter test bodies or `tests/Concurrency/writer.php`; I did not run any check, and I did not open the per-job CI results (the run page shows only the overall result).

## 1. Verdict

**Phase 4.1 is accepted.** The server now has `habit.update` with versioned definitions, `habit.archive`, `habit.restore` and `log.increment`, all through the one `MutationApplier`, with the interval rule in `nextEffectiveDate`, the `habit_archived` guard on every log write, fixtures written first and seven new mutants. The Phase 4 server gate rows are met (concurrent increments, stale absolute edit, weekly distinct days). Part 0 is done. One finding is Medium and **latent**: the app reads the wrong target once a pending version exists (P3). It does not block 4.1, but it must be fixed before any screen can create a pending version, so it opens 4.2a. Two Low findings and three Info items follow.

## 2. What I verified

| Check | Result |
|---|---|
| `666e754` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `666e7549b11e7518cf2b03c0a9409203b4566ebd` |
| CI run 38090520740 | Success on `666e754`, push, 3m1s: api 1m30s, docker-compose 5s, app 2m57s, e2e 1m24s. The run page shows only the overall result |
| Test counts | Pest 541 to 580 (5 Linux-only skips), Flutter 454 to 467, mutants 30 to 37. From the packet |
| `habit.update` | Owner and version check first (a missing or foreign habit is one answer, a stale version is a conflict with the canonical habit as `current`); type immutable; the whole desired state is compared with the latest version; a pending version is replaced in place, or deleted when the edit returns to the version in force, otherwise a new version starts at `nextEffectiveDate` computed from the user's calendar at apply time; the name applies at once; an identical update returns the current version with no bump and no journal row; one journal row, with the top-level fields taken from the latest version row |
| `habit.archive` / `habit.restore` | Archive closes the open range at the start of tomorrow, and deletes a range that starts tomorrow or later (the same-day restore case, marked `A34-empty-range`). Restore opens a range at max(today, previous end). Both are acknowledged without a bump when already in that state. `HabitSchedule` accepts adjacent ranges (it refuses only an overlap), so two ranges that touch are valid |
| Guards | `habit_archived` on `habit.update`, on every `log.*` write in the applier's log branch before the operation is resolved, and on `log.delete`. Mapped in one place (`DomainErrorMapper`) |
| `log.increment` | Validates `delta` through the type (invariant 14), resolves the day with the same code as `log.set_value` (`LogDay`), creates the log when absent, answers 409 `resource_deleted` with the tombstone as `current` on a deleted day, writes through the same tail (streak dirty, journal, closer) |
| `nextEffectiveDate` | Weekly on either side wins. For an interval old definition: the anchor if it is after today, else the next multiple of N from the anchor strictly after today. I checked the arithmetic by hand for "today is a scheduled day" and "today is between two" |
| Concurrency gate | Five writer processes, each its own PHP process against PostgreSQL, add 250 each: total exactly 1250.000, versions 1 to 5, one journal row per receipt. The test is real, but it proves serialisation by the user-row lock that the applier holds, not a per-row merge (see risks) |
| Mutants | Seven new, with names that match the rules they guard (increment as set, effective today, pending appended, archive a day late, version check removed, archived guard removed, interval period off by one). 37 of 37 from the packet |
| R1 | Photo pick, photo store, remove, profile save and the hide-names switch all catch; one neutral line each (`photoPickFailed`, `photoAddFailed`, `saveFailed`); the messenger is taken before the awaits; the edit sheet keeps its input. Switch revert: see P2 |
| R2 | `rejected` for 409, 413, 415 and 422 only; everything else except 401 and 429 backs off |
| R3 | `writeRetrying` is `transaction(write)`; it covers the engine's `_updateState`, `_update`, `_setState`, the three lease statements and AvatarSync's `_updateState` and `_defer`. See P1 for what is left |
| R4 | `JpegScrubber` matches the spec I gave: SOI, then marker segments until SOS or EOI, drops APP1, APP13 and COM, keeps APP0, APP2 and the rest, copies from SOS on byte for byte, never throws, returns the input unchanged when it cannot read it or when it is over 8 MB. `PhotoService.choose` reads, scrubs and writes, and deletes the target on failure |
| I2 | The Timezone row shows the city through `TimezoneScreen.cityName`; the id is the semantics label. A queued change also shows the city |
| Docs | BUILD_PLAN has the split; A34 and A35 are in SPEC_AMENDMENTS as written; step 26 is in DEVICE_GATE and left blank |

## 3. Findings

**P3 · Medium (latent) · Today and the library read the habit's top-level target, which A34 makes the LATEST version**
`LocalView` reads `payload['target_value']` for Today's completed state (line 192) and for the weekly progress's per-day target (line 233), and the library row reads the same field and `versions.last` for the frequency (`habit_library_screen.dart`, lines 126 to 136). A34 (my decision, matching the schema comment: "projection of the latest definition version") makes those fields the latest version, which can start tomorrow or next Monday. Until now the latest version was always the one in force, so nothing showed. From the first pending version, whether from 4.2's own edit or any other client, the new target appears on Today the moment the habit syncs, days before it governs, and a day that met the old target can show as not met. Due-ness already reads `definitions` (`HabitSchedule.fromWire(p).versionOn(date)`), and the detail view does it right in `targetOn(date)` (which uses `schedule.versionOn(date)`); these three reads are the ones that do not.
Fix (first commit of 4.2a): move that rule to one accessor for "the definition in force on a date", built on `HabitSchedule`, and use it in Today, the weekly progress, the library and the detail view. Only the edit form reads the latest. Test first: a habit whose latest version starts tomorrow shows the old target and the old completion today, and the new one on its effective date.

**P1 · Low · R3 is only partly closed**
My R3 named the engine's three helpers and AvatarSync's two, and Claude Code did exactly those; the exposure is wider than my list. Standalone writes I read and that still run without the retry: `_recoverInFlight` (called at `sync_engine.dart` lines 192, 197, 206 and 263), `_prune` and `_resumeWaiting` at lines 370 to 371, the logged-out `lastError` write in `background_sync.dart` (line 55), `_recordInvalid` in `account_calendar.dart` (line 77), and the deletes in `ReminderScheduling` (`setHideHabitNames` and `_apply`, lines 168, 185 and 222). The writes inside the apply and bootstrap transactions (`_rebase`, `_remap`, `_rejectOrphans`, `_resumeChildren`, the calls at lines 481 to 485, the calendar merge) are covered by those transactions. I did not trace every other write in the app. A refusal there ends a run with an error and the next cycle repeats safely, so this is flakiness, not data loss.
Fix: route those writes through `writeRetrying`, and add a test that forces a refusal at `_recoverInFlight`.

**P2 · Low · The Hide-habit-names switch can revert to the wrong value**
`setHideHabitNames` commits the setting first and then cancels, clears and replans. If the cancel or the replan throws, the setting is saved but the new `catch` puts the switch back to `!on`, so the screen says "off" while the stored value, and the next replan, say "on".
Fix: on failure read the stored value again and show that; test with a scheduler that throws on cancel.

**I1 · Info · A pending version's number can be reused**
Replacing or removing a pending version frees or rewrites its number, and a log written inside the 5-minute future tolerance just before local midnight resolves to tomorrow and so to that pending version. I did not check whether anything reads `habit_logs.definition_version` back. If something does (Phase 5 XP or insights), a pending version that a log references must not be replaced in place; start a new one instead. Check when Phase 5 starts.

**I2 · Info · The effective date is decided when the edit reaches the server**
`today` is taken at apply time. A phone that edits offline gets its date when it syncs, not the day the person edited. The edit screens must not promise a date: say "from the next eligible period" until the habit arrives with the pending version, then "from Monday 14 Oct".

**I3 · Info · Two small leftovers**
BUILD_PLAN's `nextEffectiveDate` bullet still shows the one-argument signature; and `ApiException::resourceDeleted` has two docblocks stacked above it. Fix both in 4.2a's docs commit.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 Empty range: archiving a range that has not started deletes it (`ASSUMPTION(A34-empty-range)`) | Accepted. It starts tomorrow or later, so no log can sit in it, and a later restore recreates it from the previous range's end |
| 2 `resourceDeleted` gained an optional `current` | Accepted (see I3) |
| 3 `startWriter` moved to `tests/Support/writers.php` and takes the frozen time | Accepted |
| 4 `AppDatabase.writeRetrying` and the HTTP-level R2 tests | Accepted |
| 5 The replacement of the Phase 4 section dropped the old "Before any `profile.*` mutation" bullet (my prompt said to keep two bullets and the gate) | Accepted: that work shipped in 2a, 2b.1 and 3.1 |

## 5. Answers to the open questions

1. **Restore on the archive day.** Two adjacent ranges are intended and valid. The domain accepts a range that starts where the previous one ended, and every date is in exactly one of them. Merging would add a rewrite of history for no gain. Keep it; the Phase 6 export lists both.
2. **Increment on another user's habit.** Keep `dependency_pending`, the same as `log.set_value`. It reveals nothing about whether the id is foreign or missing (invariant 2), and one rule for every `log.*` is easier to hold than two. The habit operations answer `not_found` because the client always knows the habit it edits.
3. **Gate wording.** The existing stale-edit test is the same rule at versions 1 and 2. No second test.

## 6. Risks to keep in view

- **Latent display bug (P3)** until 4.2a lands.
- **The app cannot send these operations yet**, so nothing in the app can archive a habit and the reminders that "still fire" cannot arise from the app. 4.2a must put the planner change and the archive operation in one phase, planner first.
- **Concurrency rests on the user-row lock.** If that lock is ever narrowed (for throughput), the increment test is the guard that fails; keep it.
- **Category is versioned (A4).** A category-only edit takes effect from the next period like a target change. The library will show the latest value, the insights the one in force. Acceptable; say so on screen 09.
- **Real-device behaviour is still unproven**: the device gate has not been run (steps 1 to 14 and 16 to 26).
- **Flaky tests are fixed by one cause found.** The profile tests' fake JPEG; three clean runs are not proof. Watch the next CI runs.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone, steps 1 to 14 and 16 to 26. Step 26 (an upright portrait photo) decides whether the scrubber is safe on that phone's cropper.
2. Commit this review file in `docs/reviews/` (Claude Code does not write there).
3. The legal items are still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, Pages source and the first publish.
4. Phase 4.2a, then 4.2b and 4.3: split below (the prompt for 4.2a follows in the reply).
   - **4.2a** (app data layer and planner): P3 first, P1, P2, I3; the local write path for edit, archive and restore; the overlay and archived views; engine acknowledgements for the new operations; the planner changes (archived, rename, caps, weekly goal met); e2e.
   - **4.2b** (screens): the type-widget registry, create (08), frequency selection (10), edit (09), library (07) and Archived routines (22).
   - **4.3** (logging): amount entry (34), timers (33 and 36), conflict review (19), Today cards, e2e, device-gate steps.
