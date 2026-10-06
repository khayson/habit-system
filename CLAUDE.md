# CLAUDE.md — Habit System

Khay Studios project. Claude (in chat) is architect/reviewer; Claude Code builds.
Work phase by phase (`docs/BUILD_PLAN.md`). Stop at every phase gate and post a review packet.

## Source of truth (highest wins)

1. `docs/SPEC_AMENDMENTS.md` — **ADOPT** items are binding. **DECIDE** items were confirmed by Khay Studios on 2026-10-06 with their recommended defaults and are equally binding.
2. `docs/spec/habit-system-spec-v1.pdf` — behavior, schema, API, acceptance tests.
3. `docs/spec/habit-design-system.pdf` — visuals only. Static; nothing in it is wired. **Every screen in it is in scope**: phases order the work, they never drop a screen. New habit types and features need their own design drop before UI is built (`docs/EXPANSION_PLAN.md`).

If two sources conflict: stop and ask. Never resolve silently.
The spec PDF's text layer drops minus signs, dashes and JSON punctuation. Read `SPEC_AMENDMENTS.md` §0 before trusting any number, and render the page if still unsure.
Any draft migrations or `api-contract.md` produced earlier in chat are obsolete. Do not use them.

## Layout

```
habit-system/
  api/                 Laravel, API only
  app/                 Flutter
  contract-fixtures/   golden JSON shared by PHP and Dart tests
  docs/                spec/ (both PDFs), SPEC_AMENDMENTS.md, BUILD_PLAN.md, EXPANSION_PLAN.md
  scripts/             PowerShell (pwsh) helpers
  docker-compose.yml   PostgreSQL only
```

## Stack

- **api**: PHP 8.4, Laravel 13 (A19), Sanctum, PostgreSQL 16+, Pest, Pint, Larastan. Queue driver = `database` for v1.
- **app**: Flutter 3.44.x stable, Dart 3, drift (SQLite), Provider, go_router, dio, flutter_secure_storage, flutter_local_notifications + timezone + flutter_timezone, connectivity_plus (a sync *trigger* only, never proof of connectivity), uuid (v7), workmanager (Android background sync).
- **Dev machine**: Windows + PowerShell, Android first. Emulator reaches the host API at `http://10.0.2.2:8000/api/v1`. iOS cannot be built locally.

## Invariants — violating any of these is a bug, whatever the feature

1. Clients never send, and the server never accepts: owner/user ids, xp, level, streaks, freeze balance. No `$request->all()`; FormRequests/DTOs with explicit fields.
2. Every query is owner-scoped. Foreign or missing ids → 404 with no distinguishing detail. Test every route and every `/sync` entity type.
3. Event time = UTC `timestamptz`. Business date = `DATE`. A habit's date is resolved server-side from the user's timezone history at `occurred_at` — never from receipt time, server "today", or an unchecked client date.
4. ONE `MutationApplier` is the only code that changes domain state. REST routes and `/sync` are adapters over it. The app writes through `/sync` only (A14).
5. Idempotency: `mutation_receipts UNIQUE(user_id, mutation_id)`. Same id + different payload hash → 409.
6. Every committed change (including deletes) appends to `server_changes`. `seq` is allocated per user under the user-row lock (A1). Domain write + ledger rows + journal rows commit in ONE transaction.
7. Ledgers are append-only. Cached balances (xp, freeze_balance, streak cache) must be reconstructable from them.
8. Client: write projection + outbox in ONE drift transaction before any optimistic UI. Never delete an unacknowledged outbox row. Advance the sync cursor only in the same transaction that durably applies the canonical changes.
9. Locally computed values are provisional and stored/labelled separately from server-confirmed values. The client never evaluates streaks, XP, level or freeze logic.
10. Quantities travel as decimal strings (`"250.000"`); durations as whole seconds; never floats.
11. Never log or export passwords, tokens, push tokens or reset tokens. Push tokens are encrypted + hashed (A7).
12. Copy/UX: no guilt, no loss-threat wording, no public or social features, no random-reward promises. Every status has a symbol or text, never colour alone. ≥44 px targets. Text scales.
13. Tolerant reader: unknown habit types, operations, entity fields and statuses are preserved and never crash the app or drop data (A21). Old app versions must keep syncing.
14. Habit behaviour lives in `HabitTypeRegistry` (api) and the type-widget registry (app). No `switch` on habit type outside the registry (A21).
15. Day boundaries come from the user's calendar history (timezone + `day_start_offset`, A22). Never assume midnight.
16. All local writes go through `LocalMutationService` (pure Dart, no UI dependencies, safe from background isolates). The UI, notification actions, widgets and background sync share it (A23).

## API conventions (restated from spec)

- Base `/api/v1`. Success: `{ data, meta:{ api_version, server_time, request_id } }`. Error: `{ error:{ code, message, fields? }, meta:{ request_id } }`.
- Statuses: 401, 403, 404, 409 (`version_conflict` | `idempotency_mismatch` | `resource_deleted`), 410 `cursor_expired`, 413, 422, 429 + `Retry-After`.
- `/sync` returns a per-mutation ack (`accepted` | `conflict` | `rejected` | `dependency_pending`). HTTP 200 never implies everything was accepted.
- `Idempotency-Key` header == `mutation_id`.

## Laravel rules

- UUIDv7 primary keys (verify the installed `HasUuids` yields v7; otherwise generate v7 explicitly). `jsonb`. CHECK constraints in the same migration as the table (`DB::statement`).
- Domain logic lives in `app/Domain/*` as pure classes: no DB, no `now()`; inject a `Clock`. Controllers and jobs stay thin.
- Pest. Every migration has a rollback test. Concurrency tests run on real PostgreSQL (the CI service), never SQLite.
- Pint and Larastan must pass.

## Flutter rules

Standard Khay Studios Flutter conventions apply (Provider, go_router only, singleton Dio `ApiClient` with auth interceptor, flutter_secure_storage for tokens, API calls only in services, const constructors, dispose controllers), **extended or overridden** as follows:

- **Envelope**: this API uses `data/meta` and `error/meta`, not `{success,message,data,errors}`. Adapt `ApiResponse`/`AppException` to carry `code`, `fields`, `requestId` and, for 409, the `current` resource.
- **Validation**: password minimum is 12 (not 8). Do not reuse a TLD-length-limited email regex.
- **Screens read local drift data** (streams) and are always usable offline. "Loading / error / retry" applies to sync and to explicit network actions (export, import, delete account), not to rendering Today or Habits. No artificial splash delay.
- **Local database is per account** (file keyed by user id). Logout or account switch never shares or purges another owner's queue.
- **Theme**: build `ColorScheme` plus a `HabitTokens` `ThemeExtension` from the 21 design tokens (light + dark). Do not use `colorSchemeSeed`. Control heights 44/52/64; radius and space scales from the design file.
- **Structure**: standard `lib/` layout PLUS `lib/data/` (drift tables, DAOs, outbox), `lib/sync/` (engine), `lib/domain/` (provisional progress only), `lib/notifications/`.
- **State**: Providers wrap drift watch-queries. No business rules in widgets.

## Testing

- `contract-fixtures/` is the acceptance truth; PHP and Dart suites both consume it. Add the fixture before the code that satisfies it.
- A phase is done only when its gate in `BUILD_PLAN.md` passes. Do not start the next phase before the review packet is posted and reviewed.

## Working agreement

- Small commits, one concern each, conventional messages.
- Do not invent endpoints, columns or screens. If something is missing, list it under "Open questions" in the review packet, proceed with the smallest safe assumption, and mark it in code: `// ASSUMPTION(A#): …`.
- No features outside the current phase.
- **Review packet** (end of every phase): what shipped · tests added + command output · deviations from spec/amendments · open questions · risks.