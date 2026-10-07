# Phase 1.1 + Phase 2a review

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-07
Scope: `api/` at public head `fbd167a` (CI run 37610614799, green), read at code level, plus domain probes run against `TimezoneTimeline`.

> **Packet discrepancy.** The packet cites head `c7a0bd5`. That commit does not exist in the public repo. I reviewed `fbd167a`, which is the head and the commit the linked CI run is green on. If `c7a0bd5` was a local commit that was amended or rebased away, confirm nothing from it is missing, and make sure the packet always cites a pushed SHA.

---

## 1. Verdict

| Part | Verdict |
|---|---|
| Phase 1.1 (domain fixes, tooling) | **Accepted.** |
| Phase 2a (auth, `/sync`, bootstrap, journal, receipts) | **Accepted with a Phase 2a.1 fix list.** Do the fixes before any Phase 2b code. About a day of work. Nothing in the design needs rework. |

The foundations are right. Per-user `change_seq` under the user-row lock (A1), receipts with canonical payload hashes, the savepoint around each mutation (a rejected mutation cannot poison the outer transaction), HMAC-signed cursors bound to user and type, 404-for-everything ownership, tombstones in bootstrap, and the 22 error-envelope tests are all correct and tested on real PostgreSQL.

Two findings (B1, B2) can leave a user permanently stuck, and one more (B3) is a contract gap the client will hit on day one. Those are why 2a.1 comes before 2b.

---

## 2. Answers to the packet's open questions

**Q1. When should `dependency_pending` park a mutation?**
Park only the dependent mutation, never the queue. The server stores no receipt for it, so the client simply re-sends later.
- The row moves to `waiting`. It re-enters the queue when a pull or an ack delivers the parent entity, or when the parent's own outbox row is rejected.
- If the parent is rejected, mark the child `rejected_local: parent_rejected`, keep its data, and surface it (see 2b requirements).
- Unrelated entities keep syncing. Ordering is per entity, not global.
- After 20 attempts or 24 h, surface it instead of retrying silently.

**Q2. Log-id merge and stored rejections.**
Accepted. The server uses the existing row for `(habit_id, log_date)` and never reuses a client id that exists elsewhere, so the ack's `entity_id` can differ from the mutation's. That is correct, but it becomes a contract the client must honour (B3). One addition: `log.delete` must also resolve by `(habit_id, log_date)` when the entity id is unknown to the server, because a merge can leave a client holding an id that never existed there. Storing rejections as receipts is right: a retry returns the identical outcome.

**Q3. Capabilities header.**
Accepted. One fix: an absent header currently means "no restriction". It must mean the baseline set (S4).

---

## 3. Findings

Severity: **High** can strand a user or lose data · **Medium** wrong behaviour users will hit · **Low** hardening. Line numbers refer to head `fbd167a`.

### Must fix in 2a.1

**B1 · High · One bad mutation wedges a device forever**
`MutationApplier` (lines 55–82) catches only `ValidationException`, `ApiException` and `\DomainException`. `SyncService::sync()` runs mutations through `array_map` with no per-mutation boundary. Any other throwable (a `QueryException` such as `numeric value out of range` on `habit_logs.value` decimal(12,3), a `JsonException`, a `TypeError` from an odd payload) escapes as a 500 for the whole request.
Mutations before it in the batch have already committed, so the client retries the identical batch, the same mutation fails again, and the ordered outbox can never advance.
Fix:
- Wrap each mutation in a `Throwable` boundary. `report()` it, and return a `rejected` ack with `code: server_error` and `retryable: true`. Store **no** receipt, so a later deploy can accept it.
- Validate the inputs that today reach the database unchecked: value range and scale per type, string lengths, and a per-mutation payload cap (suggest 16 KB), `detail` depth and size included.
- Tests: an over-range value gets a 422-class ack, not a 500; a forced exception in one mutation of three returns acks for all three.

**B2 · High · A deleted day can never be logged again**
`LogSetValue` (line 59) throws `resource_deleted` for any tombstoned row, whatever `base_version` the client sends. `(habit_id, log_date)` is unique including tombstones, and there is no restore operation. A user who deletes a log and then logs that day again is stuck in a conflict they cannot resolve.
Fix (A29): `log.set_value` with `base_version == tombstone.version` is an explicit restore. Reuse the row, clear `deleted_at`, `version + 1`, journal an upsert. A lower `base_version` (a queued edit older than the delete) still returns `resource_deleted`, which preserves spec 07's no-silent-resurrection rule. The client's conflict sheet offers "Restore my entry" and re-queues with the tombstone version.
Tests: delete then log with the tombstone version succeeds; a stale edit still conflicts; the restore is journaled and visible to a second device.

**B3 · Medium · The ack contract for id merges and natural-key deletes is unwritten**
The server may return a different `entity_id` than the mutation carried (Q2), and `log.delete` 404s on an id the server never saw. Add to A29:
- Acks always carry the canonical `entity_id`; the client must remap the local row and any outbox rows referencing it, in one transaction.
- `log.delete` accepts `habit_id` + `date` as a fallback key.
- Fixture for each case in `contract-fixtures/`.

**S1 · Medium · Invalid cursors return the wrong status**
`SyncService::position()` returns 422 for a bad signature or a cursor ahead of the journal head. Both happen legitimately: `app.key` rotation and a database restore. The client sees "validation error" and does not know to re-bootstrap. Return **410 `cursor_expired`** for every cursor that cannot be honoured; the client's reaction (bootstrap) is safe by construction. Keep 422 only for a malformed `cursor` parameter.

**S2 · Medium · Timezone mismatch rejection is too blunt**
`DayResolver` line 42 rejects any `captured_timezone` that differs from the resolved entry, and `hintMatches` is computed but never used. Fix: if the captured zone differs but `local_date_hint` equals the server-resolved date, accept. The date is still resolved by the server, so invariant 3 holds. Otherwise reject with `timezone_context_mismatch` and include the server's calendar entry for that instant in the ack so the client can correct itself.

**S3 · Medium · `habit.create` stores the raw client `frequency_config`**
`HabitCreate` line 96 json-encodes the payload as sent, after validating a parsed copy. Unknown keys, key order and unbounded size all reach the database and every device. Store `Frequency::toArray()` (canonical) instead, and cap the payload (B1).

**S4 · Medium · Missing `X-Capabilities` header means "everything allowed"**
`HabitCreate` line 60 checks capabilities only when the header is present. Treat absence as the baseline set (`type.binary`, `type.quantity`), covering both creation and `unsupported_type` behaviour. Pulling is unaffected, because invariant 13 (tolerant reader) covers old clients. No test exists for this today.

**S5 · Medium · Refresh can strand a user when the response is lost**
`AuthController::refresh` issues a new token and deletes the current one in the same request. If the response never arrives (mobile networks), the client holds a dead token and is logged out. Instead of deleting the old token, shorten its `expires_at` to now + 10 minutes. A retry with the old token then works once more.

**S6 · Low · Login is a timing oracle for registered emails**
Line 41 skips `Hash::check` when the user is null, so unknown emails return measurably faster. Compare against a fixed dummy hash on the null path. The throttle limits the exposure; this removes it.

**S7 · Low · Loose equality decides "identical state"**
`LogSetValue` line 69 uses `$next == $current` on `LogState`. Add `LogState::equals()` that compares values through `StoredDecimal` and `detail` as canonical JSON, and use it.

**S8 · Low · Per-type unit validation**
`habits.unit` is a free string. Validate it per type in the registry (binary: null; quantity: non-empty and from the allowed set or custom with a length cap).

**S9 · Test gaps** (these would have caught B1/B2/S4/S5/S6)
No tests exist for: legacy capability behaviour, login timing, a poison-pill batch, restore-after-delete, refresh with a lost response, 410 for a restored database. Add them in 2a.1.

### Domain probes (new in this review)

I ran `TimezoneTimeline` against 12 zone/date cases, each at day-start offsets 0 and 90 minutes, checking that every day start and end round-trips through `localDateAt`.

**Passed:** America/New_York (spring-forward 23 h, fall-back 25 h), Australia/Lord_Howe (30-minute DST, 23.5 h and 24.5 h days), Africa/Casablanca (Ramadan clock change), and the midnight-gap zones America/Sao_Paulo (2018), America/Havana, Asia/Beirut, America/Santiago and Africa/Cairo (the day starts at the transition, giving a 23 h day). The boundary logic is solid.

**D1 · Medium · The timeline accepts a history that violates A26 (carry; fix with `profile.set_timezone`)**
`TimezoneTimeline` does not itself guarantee that dates never go backwards. A history with Auckland → Los Angeles effective at an arbitrary instant (2026-03-10T12:00Z) goes from date 2026-03-11 to 2026-03-10 across that instant. The same change at A26's instant (next local day start in the old calendar) has zero backwards steps. So enforcement belongs in the code that creates entries, which does not exist yet. Build it as a domain method (`CalendarHistory::appendChange()`, pure, injected `Clock`) that computes the A26 effective instant, with the probe scenario as a fixture. Also add a cheap monotonic-date assertion at construction so a bad history fails loudly instead of resolving quietly.

**D2 · Medium · Ordinary travel can skip a calendar date entirely (carry into Phase 3)**
With an A26-compliant effective instant, Pago_Pago → Auckland on 2026-03-11 skips the date 2026-03-11: no instant maps to it, so `startOfLocalDay(d)` equals `startOfLocalDay(d+1)` and the day has zero length. The same happens with real zones (Pacific/Apia 2011-12-30, Pacific/Kiritimati 1994-12-31). A daily habit due on that date can never be logged, and without handling it breaks a streak through no fault of the user.
Fix (A30): a date with no instants is not part of the period grid. It is neither due nor evaluated, and it does not break or extend a streak. Add it to `PeriodEngine`, `StreakCalculator`, and `ConsistencyCalculator`, with fixtures built from these exact cases.

*Not probed, read from code only:* the daily → weekly mid-week frequency change. `PeriodEngine` governs a week by the definition in force on its first active day, so a mid-week change leaves days in no period. The carry below (`nextEffectiveDate`) removes the case.

---

## 4. Phase 2a.1 fix list (do before 2b)

In order; one commit each, with its test:

1. B1: per-mutation `Throwable` boundary, `server_error` ack with `retryable: true`, input range and size validation.
2. B2: restore on `log.set_value` with the tombstone version (A29).
3. B3: canonical `entity_id` in acks, `log.delete` natural-key fallback, fixtures.
4. S1: 410 for every unusable cursor.
5. S2: hint-aware timezone mismatch, with the server calendar entry in the rejection.
6. S3: canonical `frequency_config`, payload cap.
7. S4: baseline capabilities when the header is absent.
8. S5: refresh grace window.
9. S6, S7, S8: dummy-hash login, `LogState::equals()`, per-type unit validation.
10. S9: any remaining tests from the gap list.
11. Fold A29 and A30 into `docs/SPEC_AMENDMENTS.md` and add the new codes and fixtures to `docs/api-error-codes.md` (`server_error`).

Gate: CI green on a pushed SHA that the packet cites, mutation check still 11/11, Larastan level 8 clean.

---

## 5. Phase 2b (Flutter sync engine): requirements and watch-outs

1. **Outbox states:** `pending`, `in_flight`, `acked`, `waiting` (dependency), `blocked` (retryable server error, with attempt count and backoff), `rejected` (final, user data kept). Never delete an unacknowledged row (invariant 8).
2. **Coalescing:** collapse consecutive `set_value` rows for the same habit and date only while they are `pending` (never sent), inside the same drift transaction as the new write. Sent or in-flight rows are never touched.
3. **`captured_timezone`:** send the zone from the user's calendar entry that the server has, not the device zone. A device zone change goes through `profile.set_timezone`.
4. **Rejected rows hold user data:** show them in a "needs your attention" list with retry and discard, where discard is a recorded user action. Never drop them silently.
5. **Apply changes only if `version >=` local version.** Bootstrap and pull can overlap. Keep tombstones for ids the client has never seen.
6. **Ack remapping:** when `ack.entity_id` differs, remap the local row and every outbox row that references it, in one transaction.
7. **410 → bootstrap:** keep the outbox, replay from the snapshot cursor, and re-apply unsynced local projections over the snapshot as the provisional layer.
8. **Transport:** chunk to ≤100 mutations per request (413 otherwise), honour `Retry-After` on 429, exponential backoff with jitter on 5xx, and on 401 try refresh once and then log out while preserving the per-account database and its outbox.
9. **Multi-isolate:** a single-flight sync lock stored in the database so the UI, notification actions and background sync cannot run concurrent syncs (A23).
10. **Contract tests:** Dart consumes the same `contract-fixtures/` as PHP, including the new B2/B3 fixtures.

---

## 6. Carries (not blocking, assigned)

| Item | Where it lands | Note |
|---|---|---|
| `nextEffectiveDate` must be the next Monday when **either** the old or the new frequency is weekly | Phase 3 (A30) | My spec gap: the code correctly implements what I wrote (current is weekly only). Fixes the mid-week period gap above. |
| `users.version` column and journaling the user entity on profile changes | Before `profile.*` mutations (Phase 4/5) | The user entity is journaled at register only; edits need versions. |
| `profile.set_timezone` / day-offset change as a pure domain method (D1) | Phase 3 | Must honour A26. |
| Zero-length date handling (D2) | Phase 3 (A30) | Fixtures from the probe cases. |
| Journal and receipt pruning indexes (`server_changes.created_at`, `mutation_receipts.committed_at`) | With the pruning job | `position()` already assumes 180-day retention. |
| `period_evaluations.user_id` (owner FK on every user resource) | Migration that first fills the table, Phase 3 | Invariant 2 without a join. |
| Does logging a not-due day earn XP? | Decide in the Phase 5 packet | My default proposal: allowed, earns the same XP, never affects a streak. Khay Studios to confirm. |