# Phase 2a.1 review

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-07
Scope: `fbd167a..0cd5a39` (the 2a.1 gate commit `c41a580`, plus the app status-screen fix `0cd5a39`), read at code level.

## 1. Verdict

**Phase 2a.1 is accepted.** Every item in the 2a review's fix list is implemented as specified, each has a test, and the gate is real. One mistake in the baseline-capabilities item is mine, not the builder's (section 3). Fix it, plus two small items, as a short prelude to Phase 2b. They need no separate review stop.

Phase 2b is split in two so the sync engine gets reviewed before screens are built on it (section 5).

## 2. What I verified

| Check | Result |
|---|---|
| `c41a580` exists, is an ancestor of the head `0cd5a39`, and the head is what `origin/main` shows | Yes |
| CI run 37616960517 | Green on `c41a580`: api (PHP 8.4, PostgreSQL 17), docker-compose config, app (Flutter analyze + test). Read from the public run page. |
| CI run 37617783586 | Green on `0cd5a39` (the app fix), same three jobs |
| Test suite itself | Not re-run here (no Composer in my workspace). I read the new tests and their assertions instead. |

Item by item (code and tests read):

| Item | Result |
|---|---|
| B1 | The `Throwable` boundary wraps the whole transaction, so a failed mutation rolls back, stores no receipt, and returns `rejected` + `server_error` + `retryable`. Idempotency mismatch is returned as an ack, not thrown, so the blanket catch doesn't turn it into a retryable error. The test uses a database trigger to fail one mutation of three, then removes the trigger and shows the same mutation is accepted. Good test. |
| B1 caps | 16 KB and 8 levels are checked before parsing. Six bad values give `invalid_value`, not a 500. |
| B2 | Restore needs `base_version == tombstone.version`, reuses the row and id, clears `deleted_at`, resets `completed_at`, journals an upsert. A lower base still gets `resource_deleted`. |
| B3 | Acks carry the canonical id; conflicts name the server's row; `log.delete` falls back to `habit_id` + `log_date`, still owner-scoped and tested. |
| S1 | 410 for every unusable cursor on both `/sync` and bootstrap. |
| S2 | Hint-aware, with `error.calendar` on the rejection. The "hint disagrees" case is a fixture. |
| S3, S7, S8 | Canonical `frequency_config`; `LogState::equals()` with canonical JSON for `detail`; per-type units. All fine. |
| S5 | The grace window never extends the old token (it only shortens), so the window can't be stretched by retrying. |
| S6 | A constant cost-12 dummy hash is the right call (computing it per request would reverse the leak), and a test pins the cost. |
| App `0cd5a39` | Correct and small: any in-flight check shows "Checking…", and a failed check clears the old success. The test reproduces the exact sequence. |

Deviations 1–5 in the packet are all accepted. Note for the client (not the server): an **ack-level** `payload_too_large` (one mutation over 16 KB) is permanent for that mutation. It is different from an HTTP 413 (batch over 100), which means "send fewer".

## 3. My mistake: the capabilities baseline (open question 1)

I specified the baseline as `binary` + `quantity` in the 2a review. That was wrong. The baseline stands for a client that predates the registry, and spec v1 has **three** types: binary, quantity and duration. A client without the header is a spec-v1 client and understands all three. The builder noticed the gap and asked; the answer is **no, that exclusion is not intended.**

Fix: `BASELINE_TYPES = ['binary', 'quantity', 'duration']`. Update A29's capabilities line and the S4 test. The test should assert all three are accepted without the header, and use the existing `FakeChecklistType` (or any key the registry lacks) to assert `unsupported_type`.

## 4. Answers to the other open questions

**Q2. Should refresh be limited to one per old token?**
Not by counting. Limit the result instead: **one full-lifetime token per user and device.**
- On refresh: issue the new token, shorten the current one to its grace window (as now), and delete every other token of the same user and non-null `device_id`.
- On login with a `device_id`: delete that user's older tokens for the same device. A re-login replaces the session.
- Then a retry loop can mint replacements but can never accumulate live tokens. Tests: three refreshes inside the window leave one full token plus one grace token; re-login on the same device leaves one.

**Q3. Does `server_error` need a server-side retry cap?**
No. The per-user `sync` throttle is the backstop, and backoff belongs to the client (section 5). Add alerting on the `server_error` rate when observability lands in Phase 7.

## 5. Prelude and Phase 2b

**Prelude (three small commits, reported in the 2b.1 packet, no separate stop)**
1. Baseline fix (section 3).
2. Token collapse per device (Q2).
3. Add to the Phase 7 plan: a database-restore runbook and a journal epoch in the cursor. Today a restore to an older backup is caught only when the client's cursor is ahead of the new head. If the restored system then writes enough changes to pass the client's old cursor, that client silently misses a range. An epoch in the signed cursor, changed by the restore runbook, makes every pre-restore cursor a 410. Changing the format later costs each client one re-bootstrap, so deferring it is safe.

**Phase 2b split**
- **2b.1 (now): data layer and sync engine, tested against the contract.** Review stop afterwards.
- **2b.2 (after review): screens 02, 03, 04 (minimal), 05 (binary only) and 18 (queue) on top of the engine, plus the two-emulator demo.**

**2b.1 requirements** (in addition to `docs/reviews/PHASE_2A_REVIEW.md` section 5, which still applies):

1. **Dart day resolution.** A Dart port of `TimezoneTimeline` + `DayResolver` that passes the same `contract-fixtures/domain/day_resolution.json` as PHP. It uses the bundled tz database (`timezone` package), never `DateTime.local` or the device zone. The client needs it for "today" and for `local_date_hint`; the server still decides. Skipped-date cases are Phase 3; do not handle them yet.
2. **Confirmed vs provisional (invariant 9).** Each local entity keeps a *confirmed* row (what the server last said, with its version) separate from the *pending overlay* derived from outbox rows. The UI reads the overlay over the confirmed row. The overlay is never written into the confirmed row.
3. **Unknown things survive (invariant 13).** Unknown entity types from a pull go to an opaque table. Unknown fields on known entities are kept in an `extra` JSON column and re-emitted untouched. Unknown habit types render as a placeholder and never crash. Add a round-trip test.
4. **`LocalMutationService`** is pure Dart, with no Flutter imports, and is the only local writer. It writes the projection and the outbox row in one drift transaction. Coalescing follows the 2a review (pending rows only, same transaction, sent rows are never touched).
5. **Engine (foreground).**
   - Single-flight across isolates using a database lease, so two engines on one file never run together.
   - Bootstrap when there is no cursor. The snapshot cursor is stored in the same transaction as the last page.
   - Push in chunks of at most 100, pull after each push, apply acks and changes in one transaction. The cursor advances only in that transaction (invariant 8).
   - Acks: remap `entity_id`; `dependency_pending` waits and resumes per the 2a review's Q1 rule; `rejected` with `retryable: true` is `blocked` with exponential backoff and jitter (1 min doubling to 1 h, surfaced after 20 attempts or 24 h); other `rejected` and `conflict` rows keep their data in a "needs attention" state (no auto-resubmit). For `timezone_context_mismatch`, store `error.calendar` and offer "file it under the server's date" as a later user action.
   - Transport: 410 → bootstrap with the outbox preserved; 401 → refresh once, then log out while keeping the per-account database; `Retry-After` on 429; 413 → smaller chunks.
6. **Auth plumbing** extends the existing `ApiClient`: token storage, refresh using the new grace window, per-account database opened by user id.
7. **Fixtures.** Switch the `contract-fixtures/sync/*` `suites` to include `dart` and have Dart tests consume them. `retryable` lives inside `error`.

**2b.1 gate (automated; CI green on a pushed SHA):**
- Dart suite consumes the day-resolution and sync fixtures.
- Engine tests against a scripted transport for: duplicate retry gives one log; a crash between server commit and ack application replays safely; an interrupted pull replays safely; delete vs queued edit; restore; merged-id remap; `server_error` blocks only its own entity; `dependency_pending` wait, resume and parent-rejected cascade; 410 re-bootstrap with the outbox intact; 401 → refresh → logout keeps the outbox; 429 and 413 handling; two engines on one database file run one at a time; unknown-type round trip.
- A short scripted run of the real engine against the real local API (documented in `DEV_SETUP`, not in CI) that creates a habit, ticks it, and converges two databases.
- `dart analyze` and Larastan clean, mutation check still 11/11.

## 6. Carries (unchanged, plus one)

All carries from the 2a review stay where they were placed. New: the restore runbook and cursor epoch, in Phase 7.