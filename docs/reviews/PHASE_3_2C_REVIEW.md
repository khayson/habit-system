# Phase 3.2c review (busy-retry, sign-out, mutants, rule 13, reminders for existing habits)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-10
Scope: `92fd794..ac419a4` (7 commits, 20 files). Read at code level: the `AppDatabase.transaction` and `isBusy` diff, the `SessionProvider.signOut` diff, the CLAUDE.md and `DEVICE_GATE.md` diffs, the live-mode wiring (router, `HabitActions`, `HabitDetail`, the editor's load, save and remove paths), and the test names and counts. I did not read the bodies of the four new test files, the 12 Reminder row widget, or the mutant definitions. I did not run Dart, Pest or the mutation check (CI ran the first two). I did not see the two screenshots.

## 1. Verdict

**Phase 3.2c is accepted.** K1, K2, K3, K4 and K6 are closed. Phase 3 now waits only for the real-device gate (`docs/DEVICE_GATE.md`, 19 steps), which is Khay Studios' to run on this build. Two Low findings below can ride along with the next app change.

## 2. What I verified

| Check | Result |
|---|---|
| `ac419a4` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `ac419a4c69d78e2668fc40c635c6ffc446d04837` |
| CI run 38007804620 | Success on `ac419a4`, push, 2m35s: api 1m16s, docker-compose 6s, app 2m31s, e2e 1m16s |
| K2 | `started` is set inside the body passed to `super.transaction`, per attempt; the catch rethrows if `started`, so a BUSY from the body or from COMMIT surfaces and the body never runs twice. `isBusy` matches an in-process `SqliteException` (code 5), a `DriftRemoteException` carrying one, and a `DriftRemoteException` whose text contains "database is locked". Backoff is 5 ms times the attempt, up to 50 attempts (about 6 s) |
| K3 | `endForLogout()` is inside `try`/`on Object`, then `_auth.signOut()` always runs. Two tests (one failing plugin each) were shown failing on the old code |
| K6 | Two mutants added; the packet reports 22 of 22 killed (I did not run it) |
| Rule 13 and rule 6 | Rewritten as I gave them |
| `DEVICE_GATE.md` | Step 8 rewritten; steps 16 to 19 added (edit, off, remove, add); the 14-day limit stated at the top; table renumbered |
| Live mode | Add uses `createReminder` with `device_zone`; edit sends the whole desired state and keeps the reminder's own zone mode; remove is a `reminder.delete`. All three go through `LocalMutationService`, and the screen never calls the scheduler. The route is keyed by its URI, so "Other reminders" reloads the screen afresh. `HabitDetail` now watches `reminders` |
| Test counts | 393 to 407 is 14 new tests. By grep I count 13: 5 (live screen) + 5 (busy retry, one declaration runs for both transports) + 3 (sign-out and scheduling). The one-test gap is in files I did not open, so I take the figure from CI, not from my count |

## 3. Findings

**K2 correction · mine.** I wrote that through the drift isolate the caller "never" gets a `SqliteException`. That was too broad. I read drift's protocol code, where errors are sent as text, and missed that this only happens when the isolates are in different engines. Claude Code measured it: inside one engine the real exception arrives wrapped in a `DriftRemoteException`, and the text form appears for WorkManager's separate engine. The three-form `isBusy` is the right fix for both, and the tests drive both transports. Accepted.

**L1 · Low · Save and Remove have no in-flight guard**
`_save` and `_remove` in the live editor are async and nothing disables the button while they run. In add mode, two quick taps before the screen leaves call `addReminder` twice and create two reminders (two ids); two taps on Remove append a second `reminder.delete` that the server will answer with `resource_deleted`, which lands in screen 18. A local write is fast, so this needs a slow frame or a double-tap, but it is a data duplicate rather than a cosmetic bug.
Fix: a `_saving` flag that ignores re-entry and disables both buttons; a widget test that taps twice and counts the outbox rows.

**L2 · Low · A reminder id that is not found silently edits another**
`_loadLive` picks `mine.where(id == widget.reminderId).firstOrNull ?? mine.firstOrNull`. A link to a reminder that was removed on another device opens the habit's first reminder instead, and Save then changes that one. Fix: when `reminderId` is given and not found, show the habit's list (or leave) rather than falling back.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 K2 differs from the review | Accepted, and the correction is mine (above). Not using `openAccountDatabase` in the test is right: its fixed 15 s busy timeout cannot force a refused BEGIN. Importing `DriftRemoteException` from `package:drift/isolate.dart` is fine |
| 2 Each other-reminder time is its own button | Accepted: it lets each reminder open on its own, and every time is a 44 px target |
| 3 12's Reminder row at the end of the page | Accepted as a design gap; Phase 4 adds 09's row |
| 4 Removal as a muted text button, no dialog | Accepted (A3.2c-remove). It is undoable by adding again |
| 5 Navigation (URI-keyed 11, fall back to 12 on deep link) | Accepted |
| 6 New strings | Accepted |
| 7 Test support (file-backed session test, throwing fakes) | Accepted |
| 8 No TaskCreate in the session; `PHASE_3_2B_REVIEW.md` left uncommitted | Accepted. Leaving it uncommitted was correct (rule 8): Khay Studios adds the review files |

## 5. The open question

**Lock-screen habit names.** My recommendation: keep the habit name in the notification title, because it is what makes a reminder useful, and add a "Hide habit names in notifications" setting (default off) when Profile (20) is built in Phase 3b. The Privacy Policy draft already says that the reminder text includes the habit name and may show on the lock screen. If you would rather hide names by default, say so and it becomes the default in 3b; nothing needs to change before then.

## 6. Known limits to keep in mind when you run the gate

- Reminders are one-off alarms planned 14 days ahead, replanned on app start, resume and any write. If the app is not opened for 14 days they stop (stated at the top of the gate document).
- Live screen 11 reads the habit's reminders when it opens. An edit from another device while it is open shows on the next open.
- Background sync is best effort; opening the app is the repair path.

## 7. Next steps

1. Khay Studios runs `docs/DEVICE_GATE.md` on a real Android 13+ phone and records the 19 results. Failures come back as findings, with what you saw.
2. **Phase 3.3, Terms of Service and Privacy Policy** (pulled forward from Phase 7), with the prompt in the reply. It does not need the device gate and can run first.
3. Then Phase 3b (Profile with "Time zone" first, profile photo and location). L1 and L2 go into its Part 0.
4. Add `PHASE_3_1_REVIEW.md`, `PHASE_3_2B_REVIEW.md` and this file to `docs/reviews/` yourself.
