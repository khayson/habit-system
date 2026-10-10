# Phase 3.2b review (reminders as a synced entity, planner and scheduling, screens 11 and 04's block, A23, background sync)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-09
Scope: `27e7ea8..92fd794` (19 commits, 67 files). Read at code level: the server reminder path (migration, `ReminderWrites`, applier, presenter, bootstrap, `ReminderTest`, the two new mutants), the planner, `ReminderScheduling`, the scheduler seam and permission logic, the A23 parser, the reminder writer in `LocalMutationService`, `reminder_view`, the engine's ack and rebase path, the `AppDatabase` diff (v6 and the busy retry), background sync and its WorkManager glue, the account, session and app wiring, 08's reminder row, the Android manifest, Gradle and pubspec changes, `DEVICE_GATE.md`, and the busy-retry and two-isolate tests. I read only the top and the permission and save logic of screen 11 (385 lines), and I did not open the migration, e2e or reminder-sync test bodies or the fixtures beyond their case names. I did not run Dart, Pest or e2e (CI did). I did not see the three screenshots (they are in the session scratchpad), so visual conformance is not verified by me. For two facts about drift I read its current source on GitHub (the `develop` branch, not the pinned 2.35.1).

## 1. Verdict

**Phase 3.2b is accepted with three conditions.** The server side, the planner and the writer are sound, and I found no data-integrity defect. Phase 3 is not closed until a short **3.2c** fixes K1 to K3 below and Khay Studios runs the device gate on the 3.2c build:

- **K1** No screen can edit, disable or delete a reminder, or add one to an existing habit. This is a gap in my 3.2b scope, not a Claude Code mistake.
- **K2** The busy retry cannot trigger in the real app, and it reruns more than it says.
- **K3** A failing notification cancel can block sign-out.

## 2. What I verified

| Check | Result |
|---|---|
| `92fd794` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `92fd7947ef441bf207d122fb0f18bb581daf2bab`; `27e7ea8` is the base (19 commits) |
| CI run 37867061650 | Success on `92fd794`, push, 2m54s: api 1m11s, docker-compose 5s, app 2m49s, e2e 1m15s (job names and times from the run page) |
| Server ownership | `current()` reads by id **and** user_id under `lockForUpdate`; a foreign id answers `not_found` like a missing one; `create` with a foreign reminder id is 404 (the same pattern as `HabitCreate`); a foreign habit answers `dependency_pending`, the same as a missing one. `ReminderTest` covers all three operations and bootstrap |
| Versioning and idempotency | Base version checked; a stale base returns `version_conflict` with the current reminder; replay is `duplicate`; same id with another payload is `idempotency_mismatch`; an identical update is acked without a new version |
| Journal | One row per write, inside the applier's transaction; proved by a trigger that fails the journal insert (the tombstone does not land). A delete is a tombstone and a deleted id is not revived (`resource_deleted`) |
| Migration | CHECKs for `timezone_mode`, a non-empty `days_of_week` array of at most 7, and `version >= 1`; owner FK; the packet says the rollback test covers it (I did not read that test) |
| Bootstrap | Reminders page with the owner scope, tombstones included, before `habit_progress` and `period_evaluation`, so the evaluation page stays last |
| Planner | Gap shifts forward, a repeated hour fires once, a pending zone change applies from its effective date, off days and completed days are skipped, ids are FNV-1a over account, reminder and date folded to 31 bits. The fixture cases: spring gap, fall repeat, pending zone change, weekdays, weekly_count, device zone and disabled or archived |
| Replan triggers | I checked drift's `QueryStream`: it does **not** deduplicate results, so any write to the five watched tables (outbox, reminders, logs, calendar entries, habits) causes a debounced replan, including changes applied by a sync pull. The count-based watch query is only a vehicle for listening, so there is no missing trigger |
| Scheduling | `_apply` replaces by platform id and fire time, records every handed-over notification in the account's own database, and `cancelAll` cancels only that account's rows |
| Writer | `updateReminder` coalesces into an unsent create or update; a delete behind an unsent create is appended, never removed (invariant 8); the base version is a placeholder rebased by the engine from the ack (F4's `_rebase` is entity-agnostic, and the sync-engine prune now includes `reminder`) |
| A23 parser | Exact shape only (`log:{habit}:{op}:{value}\|slot:{date}:{reminder}`); unknown operation, bad id, value or date return null; `apply` checks and records the slot in one transaction, so a second tap or another isolate writes nothing |
| Background sync | Checks the account is still the signed-in one, never writes or clears a token, records `reauth_needed` on a 401, closes the database in `finally`. The OS glue is in `lib/background/`, so `lib/sync` stays pure Dart |
| Create flow | 08 writes the habit and its reminder in one transaction (the reminder waits as `dependency_pending` until the habit lands) |
| Two-isolate test | A real second isolate with its own connection writes 30 check-ins while this isolate syncs; 30 dates reach the server, 31 mutation ids with no duplicate. See K2 for what it does and does not prove |
| Android | `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED`, the plugin's receivers (`exported=false`), desugaring, inexact alarms with no exact-alarm permission |
| Mutation check | 20 of 20 killed (the packet's figure; the runner fails on any survivor) |

## 3. Findings

**K1 · Medium (plan gap, mine) · No path edits, disables or deletes a reminder, or adds one to an existing habit**
Screen 11's save only pops a draft (`context.pop(_draft)`). `createReminder` has one caller, `createOneTapHabit`. `updateReminder` and `deleteReminder` (and the server's update and delete) are reached only by tests and the e2e scenario. In the app this means:
- A user cannot change or turn off a reminder after creating the habit.
- Habits made before 3.2b can never have one.
- Step 8 of `DEVICE_GATE.md` ("check the habit in, then set a reminder for later today") cannot be done as written.

My 3.2b scope said "screen 11 with permission states" and did not say how an existing habit reaches it. The design's entries for 11 are 08, 09 and 20 ("return origin 09/20"), so the permanent homes are Phase 4's 09 and Phase 3b's 20, and neither exists yet.
Fix (3.2c Part A): give 11 a live mode and an interim entry, a Reminder row on 12. See §4 question 1.

**K2 · Medium · The busy retry cannot trigger in the real app, and it reruns more than it says**
Two separate problems in `AppDatabase.transaction`:
1. **Wrong exception type in production.** It catches `SqliteException`. The real opener is `driftDatabase(... shareAcrossIsolates: true)`, so the database lives in a drift server isolate. drift sends errors across the isolate as `error.toString()` and the caller receives a `DriftRemoteException` whose `remoteCause` is a string (drift's `DriftProtocol` and `DriftCommunication`). A `SqliteException` never reaches the `catch`, so the retry only works on an in-process `NativeDatabase`, which is what the tests use. In the shared topology there is one writer plus a 15 s busy timeout, so BUSY is rare and the impact today is low. But "a refused BEGIN is retried, never surfaced" is proved only for the fallback topology (independent in-process connections), not for the real one. My prompt asked for "independent connections" and did not ask for the real wrapper, so the test did what was asked; the gap is mine.
2. **It reruns more than a refused BEGIN.** The `try` wraps the whole transaction including the body. A BUSY thrown by a statement inside the body would roll back and run the body again, which is the packet's risk 4. The current bodies are database-only, but there is a cheap exact guard.

Fix (3.2c Part 0): retry only when the body never started, and recognise BUSY in the wrapper. See the prompt for the test that pins the real wrapped message.

**K3 · Medium · A failing notification cancel can block sign-out**
`SessionProvider.signOut` awaits `endForLogout()` (cancel notifications, cancel the background task) before `_auth.signOut()`. If either throws (a `PlatformException` from the plugin or a `MissingPluginException` from WorkManager), sign-out never runs: the token stays and the user is still signed in. Sign-out must always complete.
Fix: catch, record, and always call `_auth.signOut()`; test with a scheduler that throws.

**K4 · Low · `DEVICE_GATE.md` cannot be run as written and misses what 3.2c adds**
Step 8 needs K1. After 3.2c the gate also needs steps for edit, disable and delete on a real device (the OS schedule is replaced, not duplicated), and one line telling Khay Studios the known limit in K5.

**K5 · Low (a known limit, to document) · Reminders are one-off alarms for a 14-day window**
They are replanned on app start, on resume and on any write, but not by the background task (the WorkManager isolate runs the sync engine only). If the app is not opened for 14 days, reminders stop. This fits "retention by value, not compulsion" for the MVP; quick-log notification actions (Phase 8) will need the background run to top up the window. Carry, with a device check then.

**K6 · Low · The new mutants miss two owner-scope lines**
The two new mutants cover update's owner scope and delete's journal. Invariant 2 says every query and every `/sync` entity type is owner-scoped, and the two lines with no mutant are `create`'s foreign-id check and the bootstrap reminder query's `user_id`. The tests exist (`not->toContain` on bootstrap and the foreign-id loop); a mutant proves they bite. Add both.

## 4. Answers to the open questions

1. **Where do existing habits' reminders get edited?** Both, in order. Screen 11 is one screen with two modes: the draft mode 08 uses, and a live mode for a habit that exists. 3.2c adds the live mode and an interim entry, a Reminder row on 12 (a design gap: the design has no such row on 12; list it as a deviation). Phase 4 then adds the Reminder row on 09, the design's entry. Phase 3b's Profile (20) links to 11 as the design says. Decide at Phase 4 whether 12's row stays; it is cheap to keep.
2. **Should a 401 leave reminders scheduled?** Yes, that is right. A 401 is not the user's choice (a password change elsewhere, a revoked token). The database and outbox stay (G1) and the account's reminders are still the user's. A signed-out app does not replan, so they run out within 14 days by themselves, and an explicit sign-out cancels them at once (with K3 fixed). Tapping a notification opens the app at sign-in.
3. **Does the reminder's explicit `timezone` need UI before Phase 4?** No. Keep the field on the wire and validated on the server (it is a legitimate part of the contract and the planner honours it), with no UI until a design asks. 08 writes `device_zone`, as the design's "local device time" says.

## 5. Deviations

| # | Verdict |
|---|---|
| 1 `connectivity_plus` `^7.3.1` | Accepted. The stable `flutter_local_notifications` conflicts with 7.3.2 through `dbus` and the alternative was a pre-release. Add a one-line comment in `pubspec.yaml` saying why, so nobody "fixes" it by accident, and raise the constraint again when the plugin allows it |
| 2 Android build (desugaring, permissions, receivers) | Accepted; the plugin requires them |
| 3 `check.ps1` formats in batches | Accepted, and a good catch: a gate script that fails silently is worse than none. CI formats on Linux, so formatting was always checked there |
| 4 `AppDatabase.transaction` busy retry | **Not accepted as is**: K2 |
| 5 Bootstrap order | Accepted; the contract pins the evaluation page last |
| 6 Design gaps (08 row, next-due line, "Allow" banner, struck-through off days) | Accepted. "Other reminders" is built in 3.2c (it has something to list once existing habits can have reminders) |
| 7 New strings, `scheduled_notifications` table | Accepted |
| 8 ASSUMPTIONs (payload, no revival of a tombstoned id, reminder zone) | Accepted. They are contract, pinned by `reminder_entity.json`, `reminder_mutations.json` and `reminder_schedule.json` |
| 9 My untracked `PHASE_3_2A_REVIEW.md` landed in `1b885fa` | Accepted: it is the real 3.2a review (78 lines). `docs/reviews/` now lacks `PHASE_3_1_REVIEW.md`, which Khay Studios adds from the outputs folder together with this file |
| 10 Two commits with analyzer issues | The cause is my rule 13 (see §6). Fixed before the push |

## 6. Working rules

Followed: SHAs from git, the CI run id quoted, three screenshots, a packet of about 1.5 pages, ASSUMPTION markers on every invented choice, and no writes into `docs/reviews/` by Claude Code.
Slip: two commits landed with analyzer issues because the output was piped through `tail`, which replaces the command's exit code with `tail`'s. My rule 13 ("cap tool output with `| tail -40`") told it to. The rule is wrong, not the agent: rewrite it in 3.2c Part 0 so a check's exit code is always printed.

## 7. Next step: 3.2c (small), then the device gate

**Part 0:** K2, K3, K6, the rule-13 rewrite, K4's gate edits, the pubspec comment.
**Part A:** K1: screen 11 live mode, the Reminder row on 12, "Other reminders".
**Gate:** `check.ps1` and `mutation-check.ps1` (22 of 22), push, CI. Then Khay Studios runs `docs/DEVICE_GATE.md` once, on the 3.2c build, instead of twice.

## 8. Carries

| Item | Where |
|---|---|
| When a weekly goal is met, stop reminding for the rest of the week | Phase 4 (weekly periods) |
| A limit on reminders per habit and per user (the spec has none), and a planner cap on the soonest pending notifications (iOS keeps 64; Android's alarm limit is 500) | Phase 4, with multi-reminder UI |
| Habit delete or archive tombstones its reminders and cancels their notifications (the planner already skips a habit it cannot find) | Phase 4 |
| Background run tops up the 14-day window (K5) | Phase 5 or 8, with a device check |
| Lock-screen text shows the habit name. A "hide habit names in notifications" setting is a product question for Khay Studios, raised when Profile settings are designed | Phase 3b or 7 |
| `local_settings` keys `notification_action:*` are never pruned | Phase 5, when the action buttons ship |
| Two devices editing one reminder offline: the second lands in screen 18 (no auto-rebase, as for every entity except `profile.set_timezone`). Revisit if the device gate shows noise | Open |
| iOS: the scheduler initialises Android only; iOS permission, `BGTaskScheduler` registration and the 64-notification cap come with the first iOS build | Phase 7 |
| A replan reads one log per habit per day of the window; fine at this scale, batch it if habits grow into the dozens | Later |
| Earlier carries (`protected_in_streak`, pwned-password CA check, console command and journal retention, authoritative bootstrap after an epoch change, database encryption, timezone-database age) | Unchanged |
