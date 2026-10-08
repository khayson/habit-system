# Phase 2b.2 review (engine fixes, e2e job, walking-skeleton screens)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-07
Scope: `660fed0..31986ac`. Read at code level: the whole `sync_engine.dart`, `local_mutation_service.dart`, `account_calendar.dart`, the `LocalView` additions, `ApiClient`, `AuthService`, `main.dart`, session and sync providers, `HabitActions`, the router, the e2e tool and CI job, and the account-creation, needs-attention and copy files. I have no Dart toolchain here, so I did not run the Dart tests or the e2e script; CI did.

## 1. Verdict

**Phase 2b.2 is accepted.** Phase 2 (the walking skeleton) is complete. F1–F10 are implemented as specified, the e2e job is a genuine safeguard, and the screens follow the rules (offline reads from local data, text with every status, no guilt copy, no splash delay). One wiring problem (G1) and four small items (G2–G5) go first in the next phase's work.

Phase 3 is large, so it is split like Phase 2: **3.1 is the server side, 3.2 the app**. Section 5 has the scope and one design decision (A32).

## 2. What I verified

| Check | Result |
|---|---|
| `31986ac` is the head of `origin/main` | Yes |
| CI run 37695041081 | Green on `31986ac`: api, app, docker-compose and e2e (read from the run page) |
| F1 | Rows are claimed (select + mark in flight) inside one transaction; the hook test fails on the old code, as the packet says |
| F2 | `run()` catches everything. Items that fail to decode are kept raw as `undecodable:<entity>` and the cursor advances. |
| F3 | `run()` is single-flight; the same-owner lease clause is gone; the lease is re-checked inside the apply and bootstrap transactions |
| F4 | One row per entity per request; `_rebase` rewrites later unsent rows from each ack. Checked the SQL: it only touches rows after the acked one, so a concurrent edit from another device still correctly produces a conflict. |
| F5, F6, F7, F8, F10 | Implemented as specified (single-flight refresh, enforced Retry-After and persisted backoff, pause after 3 request rejections, missing-ack and re-bootstrap caps, server-time skew) |
| A31 | Client side done as designed |
| e2e job | Boots Laravel on PostgreSQL and runs six scenarios through the real engine: merged ids, conflict then discard, delete + restore across devices, a simulated restore (410 and re-bootstrap), refresh in the grace window, and convergence of both databases |
| Copy | No loss-threat or guilt wording in the strings I scanned |

Deviations 1–10 in the packet are accepted. Deviations 1, 3 and 5 (no tab bar, no background-sync row, minimal 04) are right: nothing in the app should lead to a screen that doesn't exist. The unpushed amend (deviation 10) is harmless.

## 3. Findings

**G1 · Medium · Two places decide what a 401 means, and in the app the engine's version never runs**
`HttpSyncTransport` uses `ApiClient.dio`. The `ApiClient` interceptor clears the token and calls `onUnauthenticated` on any 401 (when the request carried the stored token). `SessionProvider.handleUnauthenticated` then closes the account. So the engine never gets to run its "401 → refresh once" path in production; the tests pass because they use fakes and a bare Dio. In practice the damage is small, because a refresh with a token the server already rejects also fails. But the engine and the app now disagree, and `AuthService.logout()` called by the engine does not tell `SessionProvider`, so if the interceptor ever stops owning this, the UI would stay on Today while signed out.
Fix: one owner. The interceptor owns the end of a session. The engine's 401 handling becomes: if the stored token differs from the one the request used (rotated meanwhile), retry once with the stored token; otherwise stop with `loggedOut` and do not call refresh. Make `AuthService.logout()` notify `SessionProvider`. Test with the real `ApiClient` + `HttpSyncTransport` over a fake adapter: a 401 ends the session once, the outbox and database stay.

**G2 · Low · Offline outcomes grow a failure backoff**
`offline` goes through `_recordFailure`, so a long airplane-mode period doubles the backoff to 15 minutes. Connectivity regained forces a run, so this mostly works, but a resume with weak signal can wait up to 15 minutes while the user is online. Fix: `offline` sets a short fixed floor (10 s), never doubling; the doubling stays for 5xx, `failed` and `paused`.

**G3 · Low · A user payload without a timezone clears the calendar**
`_applyUser` writes `calendarTimezone` from `user['timezone']` even when absent, so a partial user payload would set it to null and `LocalMutationService` would refuse every write ("calendar not known yet"). Phase 5 will journal user changes (XP, level). Fix: only overwrite the calendar fields that are present in the payload.

**G4 · Low · Today's order**
Answer to open question 3: sort by creation order (UUIDv7 ids are time-ordered, so the id is enough), not by name. A rename should not move a habit. Manual reordering is a later feature.

**G5 · Low · `undecodable:*` items are never retried**
They are stored for a later app version but nothing reprocesses them. Fix: when the app version changes (store the version in `sync_state`), replay `undecodable:*` through `_applyChange` once at start.

**G6 · Note · What the e2e job does not cover yet**
`dependency_pending` (offline create + tick), `server_error`, and the 401 path run only on the fake server. Add `dependency_pending` to e2e in 3.2 (a create and a tick queued offline on one device); `server_error` stays fake-only because it needs a faulty server.

**G7 · Note · Today ignores the schedule**
It lists every active habit from its start date, which is right while only daily habits can be created. Due-ness comes with Phase 3.2 (below).

## 4. Answers to the open questions

1. **Day start / "today" from one calendar entry:** enough until calendar changes exist. It stops being enough in Phase 3.1, because `profile.set_timezone` makes the new entry effective at the next local day start (A26). From then on the user entity carries the recent entries and the app builds a multi-entry timeline (3.2). The single-entry timeline would otherwise show the new zone's date before the change takes effect.
2. **Re-login and screen 04:** your reading ("first on this device") is right and better than "first ever": reminders permission is per device. In 3.2, 04 also shows whenever notification permission has never been asked on this device.
3. **Today's order:** creation order (G4).

Risks accepted: the two-emulator demo is still yours to run (the e2e job proves two devices against the real API, but a human check on real emulators is part of the Phase 2 close). The SQLite fallback flake (a refused `BEGIN` in the two-connection test) points at the classic WAL read-to-write upgrade failure, where a deferred transaction that read first cannot upgrade to a write after another connection committed. The app uses one shared connection, so it does not apply today. Carry for Phase 5, before background isolates exist: a real two-isolate test, and write transactions started as `BEGIN IMMEDIATE` on any independent connection.

## 5. Phase 3

### Design decision A32: how streaks and the heatmap reach an offline client

The client never evaluates streaks (invariant 9), but screens must work offline. So the server sends results, as sync entities, written in the same transaction that computes them:
- **`habit_progress`** (id = the habit id; read-only for clients): `{habit_id, current, longest, unit, computed_through}`; version = the streak cache's `version`. It is separate from `habit` on purpose: bumping a habit's version on every log would cause false conflicts for definition edits.
- **`period_evaluation`** (read-only): `{id, habit_id, period_key, start_date, end_date, completed, protected, definition_version, timezone, revision}`; version = revision. Created when a period closes and journaled again when a late offline log changes it.
- Bootstrap carries both through A31's `entities` array (this is its first real use), limited to the last 400 days of evaluations; older history comes from the `GET /habits/{id}/heatmap` read endpoint when online.
- Not-due days are not stored. The app gets a Dart port of the schedule's due-ness (`HabitSchedule`), pinned by the same fixtures as PHP, exactly as the Dart day resolver was.

### 3.1 Server (next)
1. App fixes G1–G5 first (small, independent).
2. D1: `CalendarHistory::appendChange()` (pure, injected `Clock`), effective at the next local day start in the old calendar; `profile.set_timezone` mutation on top of it. `users.version`, the user entity journaled on change and carrying the recent calendar entries (timezone, offset, `effective_at`). A pending (not yet effective) entry is replaced, never stacked; changing back to the current zone cancels it. `TimezoneTimeline` asserts monotonic dates at construction. Fixtures: Auckland → Los Angeles at an arbitrary instant fails the assertion; at the A26 instant it passes; Pago_Pago → Auckland skips a date.
3. D2/A30: zero-length dates in `PeriodEngine`, `StreakCalculator`, `ConsistencyCalculator`; `nextEffectiveDate` is the next Monday if either frequency is weekly.
4. Migration: `period_evaluations.user_id` + index. A32 entities and bootstrap phase.
5. `PeriodCloser` (A10): scheduler command every 5 minutes, one unique job per user, watermark `computed_through`; also runs after a mutation that touches a closed period, and lazily before serving heatmap or streak reads. Idempotent via `UNIQUE(habit_id, period_key)` + `revision`; all writes under the user lock (A1). Daily periods only (weekly arrives in Phase 4); `protected` stays false until Phase 5.
6. Streak cache recompute from `dirty_from` through `StreakCalculator`, journaling `habit_progress`.
7. Explicit backdate (≤ 30 days back, not after the user's local today) per the spec's backdate rows, with `backdate_future` / `backdate_too_old`.
8. `GET /habits/{id}/heatmap` per the spec.

**3.1 gate:** closer idempotency and crash-retry tests; a late offline log re-evaluates the closed period and journals the new revision; a mutation racing the closer on real PostgreSQL; the D1 and D2 fixtures; the new entities in `server_changes` in the same transaction as the log write; ownership 404s on every new route and entity; extended mutation check; CI green on a pushed SHA.

### 3.2 App (after the 3.1 review)
Multi-entry calendar timeline from the user entity; local tables for the two new entities; Dart `HabitSchedule` due-ness; Today with due-ness, streak and the XP chip behind `rewards_enabled` (A13c); heatmap (12) and history with backdate (13); 04 gets Edit, "Follow device time zone" and ask-on-change (using `profile.set_timezone`) plus the reminder-permission block; local reminders (11) with permission states and the DST test; account-isolated logout; best-effort background sync and the notification-action schema (A23), with the Phase 5 carry above. Real Android device gate including battery restriction.

## 6. Carries added

| Item | Where |
|---|---|
| Real two-isolate test and `BEGIN IMMEDIATE` for independent connections | Before background sync (Phase 3.2 or 5, whichever first uses a background isolate) |
| Replay `undecodable:*` after an app update | G5 |
| Authoritative bootstrap after an epoch change; database encryption decision; timezone-database age | Phase 7 (unchanged) |