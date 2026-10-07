# Build plan — Habit System

Sizes: S ≈ days · M ≈ 1–2 weeks · L ≈ 2–4 weeks of focused work. Rough, not promises.

**Loop for every phase**
1. Claude Code builds the phase against `CLAUDE.md` + `SPEC_AMENDMENTS.md`.
2. It stops at the gate and posts a **review packet** (what shipped · tests + output · deviations · open questions · risks).
3. Khay Studios pastes the packet into the architect chat. Review happens before the next phase starts.

The spec's MVP (auth, binary habits, daily logs, offline outbox + sync, heatmap/streaks, local reminders) already contains the whole sync engine — the riskiest part. That is why Phase 2 is a walking skeleton before anything else is layered on.

---

## Phase 0 — Foundations · S

- Monorepo per `CLAUDE.md`; docs and both PDFs in `docs/spec/`; `docker-compose.yml` with PostgreSQL 16+ only; GitHub Actions CI (api tests against a PostgreSQL service container; app `analyze` + `test`).
- Windows notes: PHP runs natively with `pdo_pgsql` enabled in `php.ini`; PostgreSQL in Docker; helper scripts in `scripts/*.ps1`.
- **api**: Laravel API-only, Sanctum, Pest, Pint, Larastan; `GET /api/v1/health`; the spec envelope (`data/meta`, `error/meta`) with `request_id` + `server_time` middleware; exception handler emitting the spec error shapes (401, 403, 404, 409, 410, 413, 422, 429); UTC everywhere; rate-limiter definitions; v7 UUID base model.
- **app**: structure per `CLAUDE.md`; drift DB boots with schema v1 (empty) and a spike proves a second isolate can open it safely (A23); `HabitTokens` ThemeExtension (light + dark); go_router with auth redirect (no splash delay); singleton `ApiClient` adapted to the spec envelope; l10n scaffolding.

**Gate**: CI green. App on an Android emulator calls `/health` and displays `server_time`.

## Phase 1 — Domain core, test-first · M

No HTTP, no DB, no UI.
- **PHP** (`api/app/Domain/`, pure, injected `Clock`): `TimezoneTimeline`, `DayResolver`, `PeriodEngine` (daily / weekdays / weekly_count / interval, active ranges, definition versions), `StreakCalculator`, `XpRules`, `FreezeEvaluator` (wallet + policy + periods → decisions, ordering per A8), `HabitTypeRegistry` + `HabitType` strategy (A21) with binary / quantity / duration registered through it. `DayResolver` and `PeriodEngine` take a per-user `day_start_offset` (A22, default 0).
- **Dart** (`app/lib/domain/`): provisional progress only — today's value vs target, weekly distinct days, pending vs complete. No streaks, XP or freezes.
- **`contract-fixtures/*.json`** written first, consumed by both suites. Each declares its seed (A12). Minimum set:
  - Day resolution: `2026-05-29T06:30:00Z` in America/Los_Angeles → `2026-05-28`; later switch to Europe/Paris does not rewrite it; DST spring-forward and fall-back (US and EU); 5-minute future tolerance; 90-day offline limit.
  - Weekly: target 3 = 3 distinct days; 3 taps on one day fail; open week is pending.
  - Streak: 17–28 May = 12 with 20 May protected and 16 May missed; an unfinished current period leaves the prior streak intact.
  - XP: complete → reverse → recomplete = net +10; 99 → L1, 100 → L2, 1,250 → L13; 240 → L3 40/100; 1,240 → 1,250.
  - Freeze: two failures + one token → exactly one protected; opt-in on 20 May is not retroactive (misses on 4/9/13/16 stay unprotected); monthly refill is idempotent; refund at cap writes a zero-delta audit row; a failed week costs 1.
  - Insights: monthly 95/125 = 76 %; weekly 9/15 = 60 % with an explicit seed.
- Property tests: closure is idempotent; balance never leaves [0, 2]; toggling nets zero XP.

**Gate**: all fixtures pass in PHP and Dart; public method signatures of every domain class included in the review packet (reviewed before any DB work).

## Phase 1.1 — Domain fixes before Phase 2 · S

R1–R5 of `docs/reviews/PHASE_1_REVIEW.md`: first calendar entry governs earlier instants; `HabitType` takes `LogState` + `DefinitionVersion` (with `config`) so non-scalar types fit (A21); domain errors map to API codes in one place; only `TimezoneTimeline` and `PeriodEngine::bounds()` compute day/period instants; nightly random-seed property run and at least eight mutants.

## Phase 2a — Walking skeleton, backend · L

- Migrations 1–4 (A18). Sanctum with UUID users (`uuidMorphs('tokenable')`, token tied to a device, A6). Auth: register / login / logout / `me` / refresh.
- `MutationApplier` with `habit.create` and `log.set_value` (aliases normalised in one place, A27), receipts, journal with A1 sequencing, `/sync` (per-mutation acks; conflicts embed the error object under `ack.error`) and `/sync/bootstrap` (A2). Domain errors mapped through the single mapper.
- Transaction shape: begin → lock the user row → receipt lookup (same hash → stored result; different hash → 409) → apply → receipt + journal rows with `seq = ++users.change_seq` → commit.

**Gate (automated)**: duplicate retry → one log; interrupted pull replays safely; delete vs queued mutation → `resource_deleted`; three days offline → three original dates; **A1 concurrency test on real PostgreSQL**; cross-owner 404 on every route and sync entity; two users behind one IP get independent `api` and `sync` limiter buckets. Then a review checkpoint before 2b.

## Phase 2a.1 — Backend fixes before 2b · S

B1–B3 and S1–S9 of `docs/reviews/PHASE_2A_REVIEW.md`: per-mutation `Throwable` boundary (`server_error`, `retryable`), restore via `log.set_value` on the tombstone version, canonical `entity_id` in acks and a natural-key fallback for `log.delete`, 410 for every unusable cursor, hint-aware timezone mismatch, canonical `frequency_config`, baseline capabilities, refresh grace window, dummy-hash login, `LogState::equals()`, per-type unit validation, and the review's missing tests. A29 records the contract.

## Phase 2b.1 — App data layer and sync engine · M

Requirements in `docs/reviews/PHASE_2A_REVIEW.md` §5 and `docs/reviews/PHASE_2A1_REVIEW.md` §5: Dart `TimezoneTimeline` + `DayResolver` passing `day_resolution.json`; confirmed rows separate from the pending overlay derived from the outbox (invariant 9); unknown entity types, fields and habit types survive (invariant 13); per-account drift database (habits, habit_logs, outbox, sync_state); pure-Dart `LocalMutationService` as the only local writer (A23); foreground sync engine with a database lease, bootstrap, chunked push, transactional apply, ack remapping, waiting / blocked / needs-attention states, and 410 / 401 / 429 / 413 handling; auth plumbing over `ApiClient`. No screens.

**Gate**: Dart consumes the day-resolution and sync fixtures; scripted-transport engine tests (duplicate retry, crash between commit and ack, interrupted pull, delete vs queued edit, restore, merged-id remap, server_error isolation, dependency cascade, 410, 401, 429, 413, single-flight, unknown-type round trip); a documented manual run of the real engine against the local API converging two databases. Review stop.

## Phase 2b.2 — Walking skeleton screens · M

Screens 02, 03, 04 (minimal), 05 (binary only) and 18 (queue) on top of the 2b.1 engine.

**Gate**: app-side tests for the screens; manual demo: two emulators converge.

## Phase 3 — MVP complete · L

- **Calendar changes (D1, A26):** `CalendarHistory::appendChange()` as a pure domain method (injected `Clock`) that computes the effective instant (the next local day start in the old calendar); `profile.set_timezone` and day-offset changes go through it. `TimezoneTimeline` asserts monotonic dates at construction so a bad history fails loudly. Fixture to write first: Pacific/Auckland → America/Los_Angeles effective at an arbitrary instant (2026-03-10T12:00Z) produces a backwards date (2026-03-11 → 2026-03-10); the same change at the A26 instant produces none.
- **Zero-length dates (D2, A30):** a local date with no instants is not part of the period grid (not due, not evaluated, neither breaks nor extends a streak) in `PeriodEngine`, `StreakCalculator` and `ConsistencyCalculator`. Fixtures to write first: Pacific/Pago_Pago → Pacific/Auckland at the A26 instant skips 2026-03-11; real-zone cases Pacific/Apia 2011-12-30 and Pacific/Kiritimati 1994-12-31.
- `HabitSchedule::nextEffectiveDate()` returns the next Monday when **either** the old or the new frequency is weekly (A30), so a frequency change never leaves days outside every period.
- `period_evaluations.user_id` (owner FK on every user resource) in the migration that first fills the table.
- Streak cache + `period_evaluations` (daily), closure runner (A10), heatmap endpoint + screen 12, history and ≤ 30-day backdate (13), local reminders with permission states (11), token refresh, account-isolated logout, best-effort background sync (through `LocalMutationService`), notification action payload schema (A23), XP chip behind a flag (A13c).

**Gate**: the spec's MVP list; real Android device incl. battery restriction; DST reminder test.

## Phase 3b — Profile photo and location · S–M

- Migration for the A20 columns; `profile.update` and `profile.set_timezone` mutations; avatar upload / read / delete endpoints and the image pipeline; private object storage (local disk in dev); Profile (20) with photo picker + crop, location fields and the durable `pending_uploads` queue.

**Gate**: EXIF/GPS stripped (test image); oversized, polyglot and decompression-bomb inputs rejected; cross-owner avatar read → 404; photo visible offline and uploaded after reconnect; account purge removes the objects.

## Phase 4 — Habit types and schedules · L

- Quantity and duration; amount entry (34) and timers (33/36); weekdays / weekly_count / interval; versioned edits (09/10); archive / restore (22); conflict review (19).

- Before any `profile.*` mutation: `users.version` and journaling the user entity on every profile change (review 2a, section 6).
- The server enforces "next eligible period" for new definition versions via `HabitSchedule::nextEffectiveDate(LocalDate $today)` (daily/weekdays → tomorrow; weekly → next Monday; interval → start of the next period under the current definition). Never accept a client-chosen effective date.

**Gate**: spec acceptance rows for concurrent increments, stale absolute edit and weekly distinct days.

## Phase 4b — Tier-1 habit types · L (needs a design drop)

- The Tier-1 types chosen in `docs/EXPANSION_PLAN.md` (checklist, limit, rating, measurement) plus universal log notes. Each type is a registry entry (A21); no type-specific branching elsewhere.
- **Blocked until** Khay Studios supplies Figma for each type: Today card × 4 states, entry control, create/edit fields, detail view.

**Gate**: per-type fixtures (rule, timing, XP, insights); an old-app-version simulation syncs a new type without data loss or a crash.

## Phase 5 — Rewards and freezes · L

- Decide in the packet: does logging a not-due day earn XP? Architect's default: allowed, same XP, never affects a streak (Khay Studios to confirm).
- XP entitlements + ledger; freeze ledger / usage / policy versions; monthly job; late-completion reconciliation; screens 06, 16, 17, 35; insights 14/15; enable `rewards_enabled`.

**Gate**: spec rows for XP toggling, level boundaries, two failures / one token, monthly refill retry, late protected completion with cap audit.

## Phase 6 — Account and portability · L

- Password reset + app links (A15); account deletion with status receipt; exports; imports with signed manifest (A16); milestone push (FCM; APNs once a macOS CI route exists).

**Gate**: export round-trip; bad-import preview; deletion flow; secrets absent from exports.

## Phase 7 — Hardening and release · M

- OWASP API Top 10 pass; `/sync` load test; accessibility audit (TalkBack, font scale, contrast tool); store listing; hosted Terms of Service and Privacy Policy (screen 03 links them and both stores need a privacy-policy URL); a web page for account-deletion requests (Google Play expects one; check current store requirements); iOS verification when a Mac route exists. Production PHP has a current timezone database; log `timezone_version_get()` at boot. A database-restore runbook, and a **journal epoch inside the signed sync cursor** that the runbook changes, so every pre-restore cursor gets a 410 even after the restored journal passes the client's old seq (Phase 2a.1 review §5). Alerting on the `server_error` ack rate. The journal and receipt pruning job (180-day retention) with indexes on `server_changes.created_at` and `mutation_receipts.committed_at`.

## Phase 8 — Retention pack · L

- Quick-log notification actions and home-screen widgets (Android first), on-device smart-reminder suggestions, weekly review ritual (`weekly_reviews`, A23), starter packs, comeback flow (`habit.pause`, shrink-and-restart). **Gate**: a notification action logs a habit with the app closed, and the log syncs exactly once. See `docs/EXPANSION_PLAN.md` §6.

## Phase 9 — Tier-2 types, achievements, correlation insights · L

- Time-of-day, period-total goals, challenges, multi-slot; deterministic personal achievements; correlation insights over rating data.

## Phase 10 — Integrations · L

- Health-platform-backed values (Health Connect on Android first) and companion surfaces. Needs a privacy review first.

---

## Prompts to paste into Claude Code

**Phase 0**
```
Read CLAUDE.md, docs/SPEC_AMENDMENTS.md and both PDFs in docs/spec/.
Execute Phase 0 of docs/BUILD_PLAN.md only. Honour every invariant in CLAUDE.md.
Stop when the Phase 0 gate passes and post the review packet.
```

**Phase 1**
```
Execute Phase 1 of docs/BUILD_PLAN.md. Write contract-fixtures first (spec worked
examples + the DST/offline cases in the plan, each with an explicit seed), then the pure
PHP domain classes until the fixtures pass, then the minimal Dart mirror.
No HTTP, no DB, no UI. Stop at the gate and post the review packet, including the
public method signatures of every domain class.
```

**Any later phase**
```
Re-read CLAUDE.md and docs/SPEC_AMENDMENTS.md. Execute Phase N of docs/BUILD_PLAN.md only.
Stop at its gate and post the review packet.
```