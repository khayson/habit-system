# Phase 3.2a review (Part 0 fixes, typed derived entities, multi-entry calendar, screens 04/05/07/12/13)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-08
Scope: `1cf7320..27e7ea8` (19 commits, 72 files; about 39 source files). Read at code level: the H1–H5 server changes, the `TimezoneTimeline` and `CalendarHistory` rewrite, `PeriodCloser`, the job and scheduler entries, the sync engine diff, `calendar_store`, `AccountCalendar`, the writer (`setLogValue(logDate:)`, `setTimezone`), the heatmap/detail read model, and the timezone status. I skimmed the screens and did not run Dart, Pest or e2e (CI did). I did not see the emulator screenshots (they are in the session scratchpad), so visual conformance with the design file is not verified by me.

## 1. Verdict

**Phase 3.2a is accepted.** All five Part 0 fixes are correct, and I re-ran my own calendar probes against the H1 rewrite: 1,847 zone changes accepted and 12,929 date-boundary checks, 0 problems, with no date going backwards and no observed date reported as zero-length. Nine of the 17 × 16 zone pairs I tried are refused, all of them jumps of more than 24 hours westward (Kiritimati and Chatham to Pago_Pago or Niue; Kiritimati, Chatham, Auckland, Apia and Tonga to Etc/GMT+12), and refusing them is correct (see §4, question 4).

## 2. What I verified

| Check | Result |
|---|---|
| `27e7ea8` is the head of `origin/main`; `7f38a75` (Part 0) is an ancestor | Yes |
| CI run 37810605454 | Success on `27e7ea8`, push, 2m27s: api, docker-compose, app, e2e listed (overall result only; per-job status not itemised) |
| H1 | New `startOfLocalDay` = first instant whose date is this date or later, per entry interval; `isZeroLength` = the date at that start is later. Verified by my probe (above). Dart gets the same fixture |
| H2 | `refreshHabit` reads a habit's evaluations once; `bounds()` only on write; no read-back after writes. A closed day's result alone decides (bounds cannot change after the day began, A26) |
| H3 | `uniqueFor = 600`, `failed()` logs the user id only, `withoutOverlapping(10)` |
| H4 | Per-item transaction, `on Object` continue, version stored regardless |
| H5 | `users.calendar_journaled_at` set at registration, by `ProfileSetTimezone` and by the closer; `calendarChangedSinceJournal` is one column read |
| Rebase-once | A conflicting `profile.set_timezone` is re-sent once as a **new mutation id** on the server's current version. Right call: the server keeps a receipt for the conflict, so the old id would be an `idempotency_mismatch` |
| Calendar merge | Entries merged by `effective_at`; a pending entry the server no longer lists is removed; settled entries are never deleted except pruned beyond 120 days down to the newest; an invalid history falls back to settled entries and records `calendar_invalid` without a write loop |
| Writer | `setLogValue(logDate:)` validates before writing and emits `date_mode: backdate` + `log_date`; `setTimezone` coalesces unsent rows |
| Copy | A scan test covers loss-threat wording; the strings I checked use the design's neutral words |
| Mutation check | 18 of 18 killed (the packet's figure; the runner fails on any survivor) |

## 3. Findings

**J1 · Low · The 3.1 review file in the repo is my prompt, not the review (my mistake)**
My prompt told Claude Code to "add the review to the repo if it is missing" without giving it the file, so `docs/reviews/PHASE_3_1_REVIEW.md` now holds the 3.2a prompt text (52 lines). Fix: move it to `docs/prompts/PHASE_3_2A_PROMPT.md`; Khay Studios adds the real review files; Claude Code never writes into `docs/reviews/`.

**J2 · Medium (plan gap) · Reminders have no server side yet**
The spec lists reminder definitions as server data (bootstrap carries them; reminder routes exist), and the app writes through `/sync` only (A14), but the repo has no reminder table, entity or mutation. 3.2b therefore needs a small server part before the app part, as 3.1 did for the closer. The scope is in §6.

**J3 · Low · Provisional heatmap days are marked in the spoken label only**
Invariant 9 asks for locally computed values to be labelled. Today labels them in text; the heatmap does not. Fix: one visible line under the grid when the shown month has any provisional day ("Some days are counted on this device and are confirmed after syncing."), plus a test.

**J4 · Low (latent until Phase 5) · `protectedInStreak` is off by one when today is complete**
The server's `current` includes today when today is already complete, but today's evaluation is not stored (the period is open), so `take(current)` over stored evaluations reaches one positive evaluation too far back and can count a protected day that is not in the streak. It is harmless now (`protected` is always false until Phase 5). Fix then: the server adds `protected_in_streak` to `habit_progress` and the client heuristic goes away. No work now.

**J5 · Low · l10n scaffolding was added without being listed**
A 139-string `app_en.arb` and about 1,000 lines of generated localisation code appeared, with no mention in the deviations. I accept it (one place for strings makes the loss-threat scan reliable), but unlisted additions count as mistakes, so it is recorded in BUILD_PLAN and CLAUDE.md.

## 4. Answers to the open questions

1. **Entry point for 04:** none now. The ask-on-change card covers the real need (the device moved), and Profile (20) in Phase 3b is the permanent home. Put "Time zone" first in 3b's scope.
2. **Per-habit icon:** keep type-based icons. An `icon` field needs a spec amendment (a fixed key set, validated on the server, tolerant reader); decide it with the editor screens (08/09) in Phase 4.
3. **The 3.1 review file:** see J1.
4. **More than 24 hours westward is refused (422):** accepted, and Claude Code was right to deviate from my text. I wrote that up to three later day starts could be tried; that is wrong for a gap over 24 hours, because the gap between the two calendars is the same at every day start (except across a DST change), so the new date is always behind the old one and no instant can keep dates monotonic. Refusing is the only correct outcome. The loop still helps when DST makes the gap vary. The message ("Your days cannot move to this time zone directly. Choose a nearer zone first.") is neutral; keep it. Screen 04 already surfaces a rejected row (`queuedNeedsAttention`).

## 5. Deviations

| # | Verdict |
|---|---|
| 1 No streak chip on Today (the design puts it on 12) | Accepted: layout is the design's call, and a number on the main screen can be stale |
| 2 Heatmap: 44 dp cells; future days dashed outlines; "Upcoming"/"Pending" spoken only; provisional spoken only | 44 dp accepted (target size rule). The rest accepted except the provisional marker (J3) |
| 3 History: "Target that day" line | Accepted |
| 4 Reminder block moved to 3.2b; city names for zones | Accepted |
| 5 No back arrow/avatar on tab screens; XP line to Phase 5; type-based icons | Accepted |
| 6 Dates follow the device locale | Accepted (the design's British order is a sample) |

One more correction: the packet says "your instruction to follow the design file over the prompt". That was not an instruction. The order in CLAUDE.md stands: amendments, then the spec, then the architect's prompt, with the design file winning only on how a screen looks and reads.

## 6. Next step: 3.2b (reminders, background, device gate)

**Part 0:** working rules in CLAUDE.md (accuracy and token use); J1; J3; record l10n.
**Part A, server:** the `reminder` entity per the spec's reminder table (render the page; the text layer is unreliable), written through `MutationApplier` (`reminder.create`, `reminder.update`, `reminder.delete`, version-checked, owner-scoped, habit must be the user's), journaled, with a tombstone on delete, carried in bootstrap through `entities` (A31). The spec's REST reminder routes are not built (nothing uses them; recorded in BUILD_PLAN).
**Part B, app:** typed reminders table and writer; screen 11 with permission states; the reminder block in 04; a pure Dart planner with a rolling horizon, stable notification ids and the DST fixtures; the notification-action schema (A23, parser and tests only, no buttons until Phase 5); background sync with a real two-isolate test and `BEGIN IMMEDIATE`; account-isolated logout (cancel that account's notifications and background task); e2e for reminders across two devices. The real-device and battery-restriction check is Khay Studios' gate: Claude Code writes the checklist, you run it.

## 7. Carries

| Item | Where |
|---|---|
| `protected_in_streak` from the server (J4) | Phase 5 |
| Pwned-password check fails open on an SSL error: confirm CA setup on the production host | Phase 7 |
| Console command visits every user; journal retention for derived rows | Phase 7 |
| Reminder devices and notification-permission diagnostics (spec) | Open question in 3.2b; not needed for local reminders |
| Real two-isolate test and `BEGIN IMMEDIATE`; authoritative bootstrap after an epoch change; database encryption; timezone-database age | 3.2b / Phase 7 |
