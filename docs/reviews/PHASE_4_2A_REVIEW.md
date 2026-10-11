# Phase 4.2a review (habit edit, archive and restore in the app's data layer; reminder planner)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-11
Scope: `666e754..7cae4c2` (13 commits, 34 files outside `docs/reviews/`). Read at code level: `habit_draft.dart` in full; the diffs of `local_mutation_service.dart`, `habit_actions.dart`, `local_view.dart`, `habit_schedule.dart`, `habit_detail_view.dart`, `habit_library_screen.dart`, `provisional_type_rules.dart`, `sync_engine.dart`, `app_database.dart` (v8), `reminder_planner.dart`, `reminder_scheduling.dart`, `notification_caps.dart`, `account_context.dart`, the fixture and `architecture_test.dart` changes; the P3 test in full; the names of the new Dart tests; the assertions of the four new e2e scenarios. I also read the P2 diff and checked line ranges of the 4.1 engine against my 4.1 finding. I did not read the bodies of the other new tests, `fake_sync_server.dart`, the migration test, the generated drift file or the rest of `sync_e2e.dart`; I did not run any check, and I did not open the per-job CI results.

## 1. Verdict

**Phase 4.2a is accepted.** P3 is fixed and pinned by a test that moves a target change across its effective date; the write path for edit, archive and restore is validated, coalesces correctly in the usual cases and never merges an archive; the overlay follows invariant 9 and the "a change in needs_attention never hides a habit" rule; the planner now skips archived habits, replaces text after a rename, caps what it hands to the OS and stops reminding once a week's goal is met. Two Low findings in the new write path and one in the existing category display ride along in 4.2b's Part 0; three Info items follow. Nothing blocks 4.2b.

## 2. What I verified

| Check | Result |
|---|---|
| `7cae4c2` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `7cae4c24de1b618deb38b07f5df15737bccb1652` |
| CI run 38102709823 | Success on `7cae4c2`, push, 2m57s: api 1m30s, docker-compose 6s, app 2m52s, e2e 1m17s. The run page shows only the overall result |
| Test counts | Pest 585 (580 passed, 5 skipped; unchanged), Flutter 467 to 498, e2e 12 to 16 scenarios. From the packet; mutation-check not run, which I allowed (the only api edit is a removed docblock) |
| P3 | `HabitSchedule.inForce`, `targetOn`, `unitOn`; used by Today's completed state, the weekly progress, the library row, the detail view and the planner. The test makes another device raise the target from tomorrow: today's 2500 still completes the 2000 in force, and on the effective date 3000 is the target. One read is left (see I2) |
| P1 | `_recoverInFlight`, `_prune`, `_resumeWaiting`, the reauth write, `_recordInvalid` and the planner's deletes and insert go through `writeRetrying`. Packet deviation 2 is right and my 4.1 finding was wrong on that point: the `_prune` and `_resumeWaiting` calls I listed at lines 370 to 371 sit inside the bootstrap transaction (the block that opens at line 316), so they were never exposed. Making every path use the helper is harmless |
| P2 | After a failed change the switch re-reads the stored value (and falls back to the old position only if that read fails too), with the same one-line message |
| `updateHabit` | Validates before writing; writes nothing when the draft equals what the habit shows; folds into an unsent create; rewrites the newest pending update (keeping its base version and mutation id); otherwise appends with the newest known version (the confirmed one or an acked row's). Never queues behind a `needs_attention` row. See L1 and L2 for two gaps |
| `archiveHabit` / `restoreHabit` | Append one row each, never coalesce, write nothing when the habit already shows that state |
| `HabitDraft` | Six keys, never `type`; weekdays sorted so equal states compare equal; categories match the server's five; unit rules match the server's (`takesUnit` on the type rules: yes/no and duration take none). See I1 |
| Overlay | Unsent update, archive and restore laid over the confirmed habit, never written into it; `needs_attention` rows never hide or restore, and an edit in `needs_attention` still shows the person's text with the marker; `pendingFrom` is the effective date of a confirmed later version, never a guess; `watchArchived()` gives the local date of `archived_at` through the account timeline |
| Planner | B2: archived habits (confirmed or unsent) are left out. B3: a text key (FNV-1a over title and body, not the text) is part of the diff, v7 rows with a null key are replaced once; hidden names make a rename a no-op. B4: nearest first, ties by id, 60 on iOS and 450 on Android, injected where the scheduler is created. B5: once a Monday to Sunday week reaches its count by the rule Today uses, the whole week is marked completed |
| Schema v8 | One nullable column; `from < 6` creates the table with it, `6 <= from < 8` adds it. The v7 to v8 test and the schema-version assertion are updated, not weakened |
| Fixture consumer | `habit_mutations.json` now names the Dart suite and `architecture_test` maps it to `habit_acks_test.dart`: the rule that every fixture naming the Dart suite has a consumer is kept |
| e2e | `habit-offline` (folded edit, two adjacent ranges, one definition), `habit-pending` (a pending version, today keeps the old target), `habit-stale` (`version_conflict` kept for review with `current`), `habit-archived` (`habit_archived`, the check-in's payload kept) |

## 3. Findings

**L1 · Low · An edit can be lost when a create goes back from in flight to pending**
`updateHabit` folds an edit into the habit's create whenever that create is `pending` and unconfirmed, before it looks at later rows. A failed send calls `_recoverInFlight`, which returns an in-flight create to `pending`. Sequence: the create is in flight; the person edits (a `habit.update` row is appended behind it, base unknown); the send fails and the create is `pending` again; the person edits once more. The new edit is folded into the create, and the older `habit.update` row, still queued behind it, is applied after the create and overwrites it. The overlay shows the older values too, so the screen and the server agree, and the last edit is gone.
Fix: fold into the create only when it is the newest queued row for that habit; otherwise rewrite the newest pending update, or append. Test: create in flight, edit, failed send, edit again, sync: the second edit reaches the server and the overlay shows it.

**L2 · Low · `updateHabit` accepts an edit on a habit that shows as archived**
`_habitState` already knows `archived`, but only archive and restore read it. An update queued behind an archive row (or for a confirmed archived habit) is refused by the server with `habit_archived` and lands in `needs_attention`. The screens will not offer it, but the data layer should say no.
Fix: a fifth `HabitEditFailure` kind (`archived`), thrown without writing. Test.

**L3 · Low · The category label maps `productivity` and `other` to "Health"**
`HabitFormat.category` returns Health for anything it does not name. The server accepts five categories and the design shows three. A habit with another category (made by another client) reads as Health, and an edit form that starts from that label and saves would change it silently.
Fix (4.2b, with the edit form): labels for all five, and the category chooser keeps the habit's current value even when it is not one of the three the design offers.

**I1 · Info · The validator is a little looser or stricter than the server in two places**
The interval anchor is checked with `DateTime.tryParse`, which accepts "2026-02-31" and rolls it over; the server's `LocalDate` refuses it. And name and unit lengths count UTF-16 units where the server counts characters, so it is stricter for emoji (never unsafe). Harmless while dates come from a picker; fix with a round-trip check and `runes.length` when 4.2b routes create through the same validator.

**I2 · Info · Two small traps for the next screens**
`HabitView.inForceToday` without a clock returns the FIRST version, not the latest or nothing; make the clock required there. And `HabitActions.toggle` still reads the top-level target (`habit_actions.dart`, line 32): harmless for yes/no (the target is always 1), but 4.3's amount entry must use `schedule.targetOn(date)`.

**I3 · Info · Each replan reads about 30 days of logs per habit**
The new scan reads one log per habit per day from the week's Monday to the end of the horizon plus six days, two queries each, though days after today have no logs. A few hundred queries for ten habits, debounced; fine now. Read only up to today, or one range query per habit, when it shows.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 B1: the existing trigger already replans on a pulled reminder edit; test kept, trigger change reverted | Accepted. The B3 rename test covers a pulled habit change too |
| 2 P1: `_prune` and `_resumeWaiting` use the retry on every path; the planner's insert is wrapped | Accepted |
| 3 `ProvisionalTypeRules.takesUnit` | Accepted |
| 4 `watchHabits({deviceNow, includeArchived})`, `habits({deviceNow})` | Accepted |
| 5 `habits()` reads the outbox in one query because a second query made a timing-sensitive reminder test fail | Accepted, but a test that fails on one extra query is fragile; see Risks |
| 6 Fake-server helpers (`serverEditHabit`, `serverEditReminder`, `forceErrorFor`, habit.update, archive, restore, `habit_archived`) | Accepted |
| 7 Schema v8 with `content_key` as a hash, with migration and upgrade test | Accepted |
| 8 B5 scans from the Monday of the week containing yesterday | Accepted |
| 9 `HabitEditFailure` kinds: invalid, needsAttention, unknownHabit | Accepted; L2 adds one |
| 10 The review-file commit comes before the P3 commit | Accepted |

## 5. Open questions

None from the packet.

## 6. Risks to keep in view

- **Two fragile tests are on record**: the profile widget tests that can hang under heavy parallel load, and the reminder test that failed on one extra query. Both pass in `check.ps1`; if either shows in CI, fix the test's wait, not the product.
- **The UI must keep to the data layer's rules.** 4.2b must hide Edit for an archived habit and for one whose newest change needs a look (open the resolve flow instead), or the typed failures will surface as errors.
- **An unsent archive has no `archived_at`.** `watchArchived()` gives it no date until the server answers; screen 22 should say "Archived" without a date, or use today's date, until then.
- **Notification caps are silent.** Beyond 60 (iOS) or 450 (Android) reminders in the 14-day window, the farthest wait for the next replan; the app must be opened to refill them. The background top-up is Phase 8.
- **Real-device behaviour is still unproven**: the device gate (steps 1 to 14 and 16 to 26) has not been run.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone, steps 1 to 14 and 16 to 26.
2. Commit this review file in `docs/reviews/` (Claude Code does not write there).
3. The legal items are still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, Pages source and the first publish.
4. Phase 4.2b (the prompt follows in the reply): L1, L2, L3, I1 and I2 in its Part 0; the type-widget registry; screens 10 (frequency), 08 (create, in full), 09 (edit), 07 (library, with the archived link) and 22 (Archived routines).
