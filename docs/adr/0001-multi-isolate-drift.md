# ADR 0001 — One account database, many isolates (A23)

Status: accepted (Phase 0 spike) · 2026-10-07

## Context

The UI isolate, background sync (workmanager), notification-action callbacks and, later, widget
refreshes all need to write the same per-account drift database. They can run at the same time,
and the UI may not be running at all when a background isolate starts. All local writes go
through `LocalMutationService` (invariant 16), so whatever the isolate, writes must be safe and
the UI's stream queries must notice them.

## Decision

`lib/data/database_opener.dart` — `openAccountDatabase(accountKey)` is the only way to open an
account database, from any isolate.

1. **Shared server isolate.** drift_flutter's `DriftNativeOptions(shareAcrossIsolates: true)`.
   The first isolate to open the file spawns a drift server isolate and registers its port with
   `IsolateNameServer` under `drift-db/habit_<userId>`. Every other isolate in the same process
   finds it by name and connects. Result: one SQLite connection does all writes, and table-update
   notifications fan out to every client, so UI streams refresh after a background write. The
   server shuts down after its last client disconnects; if it vanished without unregistering,
   drift pings it and replaces it.
2. **Safe connection settings as a second line.** `configureConnection` runs on every raw
   connection: `busy_timeout = 15000` **first**, then `journal_mode = WAL`, `synchronous = FULL`,
   `foreign_keys = ON`. If two independent connections ever exist (another process, such as a
   future home-screen widget process, or a lost name-server race), SQLite's file locking plus the
   busy timeout serialises them instead of failing.

   `synchronous = FULL` (changed from `NORMAL` after the Phase 0 review, F6): in WAL mode
   `NORMAL` can lose the most recent commits on an OS crash or power loss, which would break
   "saved on this device" (invariant 8). Each check-in is a tiny write, so the extra fsync is
   negligible.
3. **One file per account**: `habit_<userId>.sqlite` in application-support storage. Account ids
   are validated as UUIDs before use in a file name. Logout or account switch never opens or
   purges another owner's file.

## Evidence

- `test/data/database_spike_test.dart` (host, runs in CI):
  - schema v1 boots empty, `user_version = 1`, WAL on, `synchronous = FULL`, foreign keys on;
  - a second isolate writes through the shared server concurrently with the UI isolate; no rows
    lost; the UI receives the background isolate's table-update notification;
  - two **independent** connections in two isolates write 300 transactions each concurrently:
    600 rows, no `SQLITE_BUSY`.
- `integration_test/multi_isolate_db_test.dart` (Android emulator): the production opener, with
  the real `IsolateNameServer`, used from the UI isolate and a background isolate at the same
  time (200 + 200 writes, cross-isolate notification, WAL and `synchronous = FULL` confirmed).

**Found on CI (Phase 2a):** with two independent connections committing back-to-back and
`synchronous = FULL` on a slow disk, a waiter's `BEGIN IMMEDIATE` was starved past a 5 s busy
timeout. The timeout is now 15 s. This only concerns layer 2; the shared-server path has one
connection and no contention.

**Bug found by the spike:** setting `journal_mode = WAL` before `busy_timeout` made a second
connection opening during the first one's WAL switch fail immediately with "database is locked".
The order is now fixed and commented in code.

## Consequences

- Background entry points must call `BackgroundIsolateBinaryMessenger.ensureInitialized` (or run
  in their own Flutter engine, as workmanager does) before `openAccountDatabase`, because the
  path lookup uses `path_provider`.
- Stream refresh across isolates relies on drift's update notifications. Raw SQL writes must
  declare the tables they touch (typed drift writes do this automatically).
- A separate OS process (not just a separate isolate) does not see the name server; it gets a
  second connection protected only by layer 2, and its writes do not refresh UI streams until the
  UI re-queries (e.g. on resume). Widgets avoid this entirely: they read a JSON snapshot (A23).
