# Phase 2b.1 review (app data layer and sync engine)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-07
Scope: `0cd5a39..660fed0` (prelude + 2b.1), read at code level: `sync_engine.dart`, `local_mutation_service.dart`, `local_view.dart`, `entity_codec.dart`, `app_database.dart`, both transports, `auth_service.dart`, `account_store.dart`, `timezone_timeline.dart`, plus the engine test list and the smoke script. I have no Dart toolchain in my workspace, so the findings below come from reading the code, not from running it.

## 1. Verdict

**Phase 2b.1 is accepted, with a fix list (section 3) that comes first in the 2b.2 work.** The design is right: confirmed rows and the pending overlay are kept apart, the cursor moves only inside the transaction that applies what it covers, unknown things are preserved, and every gate scenario has a test. The fixes are engine details, not redesign. Two of them (F1, F2) can silently lose a user's edit or wedge a device, so they must land before any screen drives the engine.

## 2. What I verified

| Check | Result |
|---|---|
| `660fed0` is the head of `origin/main` | Yes |
| CI run 37651838947 | Green on `660fed0` (api, docker-compose, app). The earlier `462c821` failure was the `dart format` vs build_runner disagreement; excluding `*.g.dart` from the format check is the right fix. |
| Prelude | Baseline is binary + quantity + duration; one full token per user and device on refresh and login; BUILD_PLAN split and Phase 7 runbook/epoch notes. All as specified. |
| Dart day resolution | A faithful port of the PHP algorithm (transition-table logic, same fixture file, `timezone` package, no device zone). |
| Not run by me | Dart tests and the smoke script (no Dart toolchain here). |

What is well done: `_apply` writes acks, changes and the cursor in one transaction; orphan children are rejected with their data kept; `_eligible` holds back only the entity (and a habit's logs) that is blocked; the 3-state `AuthSession.refresh` stops a lost response from logging the user out (deviation 1, accepted); the smoke script's own bug was reported honestly and the engine handled the rejection correctly; the architecture test keeps Flutter out of the writer, view, codec and engine. Deviations 1–3 are accepted. Deviation 2 (database stays open after an engine-triggered logout) is fine as long as no new engine run starts for that account, which F3's fix enforces.

## 3. Findings and fixes (do these first, one commit and test each)

**F1 · High (low probability, silent data loss) · Read-then-mark race can drop the user's latest edit**
`_runLocked` reads eligible rows (line 96) and marks them `in_flight` in a separate statement (line 97). `LocalMutationService.setLogValue` coalesces into the newest row while it is still `pending`. If a write (UI, a notification action, a background isolate) lands between those two statements, the stored payload changes but the engine sends the payload it already read. The server stores the old value, acks, the row is pruned as "reflected", and the user's last tap quietly reverts. Fix: select and mark in one drift transaction and build the wire payload from rows read inside it. Test: a hook between select and mark performs a coalescing write; the sent mutation must carry the new value, or the write must become a new row.

**F2 · High · One undecodable server payload wedges the app forever (the client twin of B1)**
Only `SyncTransportException` is caught. A `TypeError` from the unchecked casts (`next_cursor as String`, `change['version'] as int`, `change['payload'] as Map`, `habit['version'] as int`) or a `FormatException` escapes `run()`. The apply transaction rolled back, so the cursor never advances and every later run replays the same page and fails again. Invariant 13 says old apps keep syncing against newer servers. Fix:
- `run()` catches every other throwable: rows return to pending, `sync_state.last_error` records it, and it returns a new `SyncOutcome.failed`.
- Decode each change and each bootstrap item inside its own guard. One that fails is stored raw in `opaque_entities` (type `undecodable:<entity>`) and the cursor still advances, so a later app version can reprocess it.
- Tests: a change with a null payload, a string version, a missing `next_cursor`; the run completes and the other changes apply.

**F3 · Medium · `run()` is re-entrant on one engine, and the lease can be lost silently**
`_acquireLease` accepts `lease_owner = ownerId`, and nothing guards against a second `run()` on the same instance. In 2b.2 a connectivity event, an app resume and a pull-to-refresh will call `run()` together, and both calls pass. The two-engine test uses different owners, so it cannot see this. Fix: keep an in-flight future inside the engine and return it for concurrent callers; remove the same-owner clause (a crashed owner is recovered by expiry); make `_renewLease` check that it still owns the lease and stop the run (return `busy`) if not.

**F4 · Medium · Version arithmetic causes false conflicts (open question 1)**
`_expectedVersion` predicts the server version as confirmed + outstanding rows. An identical-state write is acknowledged without a version bump (spec 07), so a no-op ahead of another queued write leaves the next base one too high and the user gets a conflict they did not cause. Answer: do **not** change the server; fix the client so it never predicts.
- Send at most one row per entity per request (later rows for that entity go out in the next round of the same run).
- When an ack for entity E arrives, rewrite `base_version` of E's later unsent rows to the ack's `version` in the same transaction. The write-time value stays as a placeholder.
- Test: a no-op ack followed by another queued write for the same habit-day is accepted; three queued rows for one day converge.

**F5 · Medium · Concurrent refreshes can end with a dead token**
With one token per device (prelude 2), two overlapping refreshes (the engine's 401 path and `refreshIfStale`) mint N1 then N2, and the server deletes N1. If N1's response arrives last, the app stores a deleted token and the next call forces a logout. Fix: single-flight `AuthService.refresh()` (concurrent callers share one future). Background isolates must not refresh; on 401 they report and the foreground refreshes. Test: ten concurrent calls make one request.

**F6 · Medium · Backoff is not enforced**
`next_sync_at` is written on 429 and never read, so a second `run()` inside the Retry-After window hits the server anyway. 5xx and offline outcomes keep no state, so connectivity-event storms can hammer the API. Fix: `run()` returns early while `next_sync_at` is in the future; persist `consecutive_failures` and an exponential backoff (30 s doubling to 15 min, with jitter) for 5xx and network failures; clear both on success.

**F7 · Medium · Whole-request 4xx are hidden (open question 3)**
Answer: treat 403, 404 and 422 on `/sync` as they are now (back off, keep every row), but count them. After 3 consecutive ones, set `sync_state.status = paused` with the error code. Screen 18 then shows "Sync is paused" with a plain reason and an "Update the app" hint. Nothing is dropped, and the first success clears it.

**F8 · Low · Two hot loops**
A sent mutation with no ack goes straight back to pending and is re-sent immediately (up to 1000 rounds), and repeated 410s re-bootstrap repeatedly. Fix: count a missing ack as an attempt (blocked with backoff after 3), and allow at most 2 re-bootstraps per run.

**F9 · Medium · The engine is proven only against a fake server**
The 21 engine tests run on a 372-line Dart `FakeSyncServer` written beside the engine. The real-API smoke run covers create, tick and untick (`set_value` 0) only. Delete, restore, merged ids, version conflicts, `dependency_pending`, `server_error`, 410 and token refresh have never met the real server. The fake and the real API can drift apart silently. Fix: add a CI job `e2e` (PHP 8.4, PostgreSQL service, Flutter) that boots the API and runs an extended smoke with: two devices tick offline (merged id); delete on one device and restore on the other; stale edit vs another device's edit (conflict); a simulated database restore (cursor ahead of the head, then 410 and re-bootstrap); refresh with the 10-minute grace. Gate: green on a pushed SHA.

**F10 · Medium · A device clock that runs ahead is rejected for good**
The server refuses `occurred_at` more than 5 minutes in the future (`future_event`), and the app stamps mutations with the device clock. A phone running 6+ minutes fast gets every tick rejected permanently. The transport also discards `meta.server_time`. Fix: capture `meta.server_time` from every response, store `clock_skew_ms` in `sync_state`, and have `LocalMutationService` and "today" use the corrected clock. The server still decides the date. Tests: skew +10 min produces an accepted mutation.

## 4. Answers to the open questions

1. **Version arithmetic / acks:** F4 above. The server keeps its behaviour; the client stops predicting.
2. **Unknown bootstrap collections:** the principle (never drop) is right; keying by the JSON key is not. Journal entities are singular (`habit_log`), bootstrap keys are plural (`logs`), so a future server's entity would be stored under two names. Decision (A31): new entity types travel in bootstrap as one array, `entities: [{entity, id, version, payload}]`, which the client stores in `opaque_entities` by `entity`; the three v1 collections stay as they are. Any other unknown top-level list is still kept, under type `bootstrap:<key>`, so nothing is dropped. No server work is needed until the first new entity type exists.
3. **Whole-request 403/404/422:** F7 above.
4. **Opportunistic refresh:** yes, call `refreshIfStale()` in 2b.2 from the app shell on start and resume while online (single-flight, foreground only). The background-isolate piece stays with Phase 5.

## 5. Carries

| Item | Where |
|---|---|
| Authoritative bootstrap after a restore (epoch change): overwrite confirmed rows even when the local version is higher, because the `version >=` rule would otherwise keep rows the restored server lost | Phase 7, with the cursor epoch |
| Decide local database encryption (SQLCipher) before notes, photos and location land | Phase 7 |
| Timezone database in the app is frozen until an app update; log its version at start | Phase 7 |
| The user entity must carry the calendar entry (timezone, offset, `effective_at`) and be journaled on change | with `users.version` (already planned) |

## 6. Scope for 2b.2

**Screens (from the design file):** 02 Sign in, 03 Create account, 04 Timezone (minimal: confirm the zone; the reminder-permission block arrives with Phase 3's screen 11), 05 Today (binary only), 18 Offline queue and sync, **plus a minimal Create-habit flow (the editor screen; binary type and daily frequency only; no schedule or reminder sub-screens)**. I am pulling that last one forward on purpose: without it the two-emulator demo has no way to create a habit, and screens 02–05 alone cannot show a habit being created on one device and ticked on the other. It is a scope addition to the plan, not a new design.

**Rules:** screens read local data through `LocalView` streams and work fully offline; no artificial splash delay; passwords of at least 12 characters; no TLD-limited email regex; every status has text or a symbol, never colour alone; targets of at least 44 px; copy follows invariant 12; Today shows queued items with the design's "waiting to sync" label; a habit-day with a `needs_attention` row opens its resolve sheet when tapped instead of silently queueing more rows behind it; Screen 18 lists counts by state and needs-attention rows with "Discard" (confirm, recorded) and "Try again" for blocked rows. Conflict *resolution* (screen 19) stays in Phase 4.
**Triggers:** sync on start, resume, after a local write (debounced), connectivity regained (`connectivity_plus` is a trigger only) and a manual "Sync now" in screen 18, all through the single-flight engine.

**2b.2 gate:** F1–F10 fixed with tests; the `e2e` CI job green; the screens' widget tests; and the manual demo: two emulators converge (create a habit on A, tick on B while A is offline, reconnect A).