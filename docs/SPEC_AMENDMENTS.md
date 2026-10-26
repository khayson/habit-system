# Spec amendments — Habit System v1

Prepared for Khay Studios · architect/reviewer pass · 2026-10-06

**Status legend**
- **ADOPT** — binding unless Khay Studios vetoes in writing.
- **DECIDE** — a product or infrastructure call; recommended default shown. **All DECIDE items were confirmed by Khay Studios on 2026-10-06 with their recommended defaults and are now binding.**

**Precedence**: approved amendments > spec v1 > design PDF.

---

## 0. Reading notes

### 0.1 Text-extraction hazards

The spec PDF's text layer loses minus signs, en-dashes, arrows and JSON punctuation. Examples: `2026 05 28` means `2026-05-28`; `reversal 10` means −10; `between 0 2` means 0–2; JSON keys/values appear without quotes. When a number or rule looks odd, render the page and read it visually. §0.2 is authoritative for the rules below.

### 0.2 Numeric rules, restated unambiguously

**XP**
- Completion: +10, one entitlement per habit per local date.
- Reversal: −10 (append-only ledger row; entitlement state → reversed; revision + 1).
- Re-completion: +10 only after a prior reversal, recorded against the next `entitlement_revision`. Toggling nets zero.
- Partial progress and increments after completion: 0.
- `level = 1 + floor(xp / 100)` · `progress_into_level = xp mod 100` · `next_level_threshold = 100 × level`.

**Freezes**
- Cap 2; balance always in [0, 2].
- Spend: −1 per eligible closed period without completion; one spend per `(habit_id, period_key)`; a failed week costs 1 total.
- Monthly grant at start of local month: `+max(0, 2 − balance)`, once per user per month, `source_key = month:YYYY-MM`.
- Late real completion refund: `+min(1, 2 − balance)`, at most once per usage. If that is 0, write a zero-delta audit row with reason `cap_reached`.
- A freeze is never a completion: no XP, not in the consistency numerator.

**Windows and limits**
- Offline event age ≤ 90 days; future tolerance 5 minutes.
- Explicit backdate ≤ 30 days (also habit start backfill). Verified own-backup restore is exempt (A16).
- `/sync`: push ≤ 100 mutations; pull default 200, max 500.
- Journal and tombstones retained 180 days; older cursor → 410.
- List pagination default 50, max 100; heatmap window ≤ 366 days.
- Export link 24 h; account purge ≤ 30 days after deletion; private backups age out ≤ 90 days.
- Display name ≤ 80; habit name ≤ 100; password ≥ 12; `weekly_count` 1–7; `every_n_days` 1–365.
- Week = Monday 00:00 → next Monday 00:00 local; `days_of_week` 1 = Mon … 7 = Sun.
- Dates `YYYY-MM-DD`; timestamps ISO-8601 UTC with `Z`.

---

## 1. Correctness

### A1 — Commit-ordered per-user change sequence · ADOPT · critical

**Problem.** `server_changes.seq` as a global `bigint identity` is assigned at INSERT, not at COMMIT. Tx A gets 100, tx B gets 101 and commits first; a client pulls, sees 101, stores cursor 101; A commits 100 afterwards and is never delivered. That silently loses changes in exactly the multi-device, retry-heavy cases this spec targets.

**Resolution.**
- Add `users.change_seq bigint not null default 0`.
- Every transaction that writes domain state first runs `SELECT … FOR UPDATE` on the user's row (the same lock the spec already needs for the freeze wallet — one "user lock"), then allocates `seq = ++change_seq` for each journal row it writes.
- `server_changes` primary key becomes `(user_id, seq)`; drop the global identity.
- Applies to: MutationApplier (REST and `/sync`), period closure, monthly grants, import apply, purge.
- Cursor = opaque wrapper of `(user_id, seq)`.
- Because all writers for one user serialise on that lock, commit order equals seq order and `seq > cursor` pulls cannot skip rows. Per-user write contention is negligible.

**Gate test (Phase 2).** N parallel writers plus a concurrent puller on real PostgreSQL; the union of pulled changes has no gaps and no misses.

### A2 — Bootstrap endpoint · ADOPT

The spec defines `410 → bootstrap` but no route, and a fresh install, new device or reinstall needs it too.

Add `GET /api/v1/sync/bootstrap?cursor=&limit=`. Pages carry habits + definition versions + active ranges, reminders, logs (≤ 500 per page), reward/freeze summary and the user snapshot. The first page pins `snapshot_seq` (carried inside page cursors); the last page returns it. The client then calls `/sync` with `cursor = snapshot_seq`.

Pages read live rows, so a row may be newer than `snapshot_seq`. Replay is safe because the client applies an incoming change only if its version ≥ the local version and no unsent absolute edit exists (otherwise `needs_review`). Redefine "consistent snapshot" in the spec as *snapshot + idempotent replay*, not one DB transaction.

### A3 — Canonical `period_key` · ADOPT

- `d:YYYY-MM-DD` — daily, weekdays and interval periods (the scheduled local date).
- `w:YYYY-MM-DD` — weekly_count; the date is that week's Monday. Never ISO week-year strings.

Used by `period_evaluations`, `freeze_usage`, journal payloads and fixtures.

### A4 — One source of truth for habit definitions · ADOPT

- `habit_definition_versions` is authoritative for type, target, unit, category and frequency. Same-named columns on `habits` are a denormalised projection of the latest version, written only by the same service in the same transaction; historical evaluation never reads them.
- `type` is immutable after creation (changing binary → quantity reinterprets every past value). To change type: archive and create a new habit.
- Two edits resolving to the same `effective_date` update that not-yet-effective version row in place (honours `UNIQUE(habit_id, effective_date)`).

### A5 — Meaning of `captured_timezone` · ADOPT

It is the **habit-calendar zone the client was using** (its cached profile zone) when it captured the event — not the phone's physical zone. The physical zone goes to `devices.device_timezone` (diagnostic). Otherwise anyone travelling in `fixed` mode triggers `timezone_context_mismatch` on every log. Mismatch fires only when the client's cached zone disagrees with the server's timeline at `occurred_at`.

### A10 — Period closure runner · ADOPT

A scheduler command every 5 minutes enqueues one unique job per user whose next local day/week boundary has passed (watermark: `habit_streak_cache.computed_through`). The same `PeriodCloser` service also runs (a) after any mutation touching an already-closed period (late offline log) and (b) lazily before serving heatmap, insights or streaks if the watermark is stale. Idempotent via `UNIQUE(habit_id, period_key)` + `revision`. All writes take the user lock (A1).

---

## 2. Gaps and security

### A6 — Token lifetime, rotation, reauth · CONFIRMED 2026-10-06 (default applied)

Sanctum tokens do not expire or refresh by default, yet the spec expects expiring sessions. Default: `sanctum.expiration` = 120 days (longer than the 90-day offline window); `POST /auth/refresh` issues a new token and revokes the old one, called opportunistically when the token is older than 30 days and the app is online. Expired token → screen 02 with the queue preserved (per spec). Reauth for `DELETE /me` (and password change): require the current `password` in the request body; no separate reauth route.

### A7 — Push token uniqueness · ADOPT

Laravel's `encrypted` cast uses random IVs, so a UNIQUE index on `push_token` cannot work. Store `push_token` (encrypted) + `push_token_hash` (HMAC-SHA256, dedicated key); partial unique index on `push_token_hash WHERE revoked_at IS NULL`; look up by hash.

### A14 — App writes go through `/sync` only · ADOPT

One write path to test. REST write routes in the contract stay as thin adapters over the same MutationApplier (contract tests, a future web client, admin tooling) and may land after the app works.

### A16 — Export / import hardening · ADOPT

- CSV: neutralise formula injection in user-controlled cells (cell starts with `=`, `+`, `-`, `@` → prefix with `'`), plus standard escaping.
- "Verified own export": the JSON manifest carries `kid` and an HMAC-SHA256 signature over canonical JSON, bound to `user_id` + `snapshot_seq`; import verifies it; rotate keys by `kid`. Without this, a "verified backup" cannot legitimately bypass the 30-day backdate limit.
- Passwords: minimum 12 (spec) and reject known-breached passwords (`Password::uncompromised()`).

---

## 3. Product decisions

### A8 — Which habit gets a freeze when tokens are scarce · CONFIRMED 2026-10-06 (default applied)

Spec order: period end, then habit UUID. UUID order is arbitrary, so which streak survives looks random to the user. Default: `ORDER BY ends_at ASC, streak_at_risk DESC, habit_id ASC` — protect the longest streak first, UUID only as the final tiebreak. Still deterministic and testable.

### A9 — Level and progress are server fields · ADOPT

`/me`, `/rewards` and the user sync entity return `xp`, `level`, `progress_into_level`, `next_level_threshold`. The client never evaluates the formula; offline it shows "+10 pending" without changing level. This lets the curve change without an app release. Note: linear levels mean five habits a day is a level every ~2 days, so numbers will inflate fast — acceptable for v1, now cheap to change.

### A11 — Initial freeze balance · CONFIRMED 2026-10-06 (default applied)

Spec does not say how the balance starts or whether opted-out users accrue. Default: grant 2 at account creation (`source_key = signup`) and top up monthly regardless of opt-in; opt-in gates **spending** only.

### A12 — Golden fixtures need explicit seeds · ADOPT

The spec's worked numbers are the acceptance fixtures (3/5 → 4/5, 1,240 → 1,250 XP, 9/15 = 60 %, 95/125 = 76 %, streak 12 with 20 May protected). They reconcile only for the five daily/weekday habits: with Running (Tue/Sat) in the data set, Tue 26 May is a sixth due period (denominator 16, not 15) unless Running started later. Every fixture must declare habits, start dates, schedules, timezone, freeze-policy history and logs explicitly. Khay Studios confirms the Running case during Phase 1.

---

## 4. Design ↔ spec reconciliation

### A13 — Design file vs spec · ADOPT

**Policy (Khay Studios, 2026-10-06): every screen in the design file is in scope and will be built. Phasing orders the work; it never drops a design.** Where a design shows data the spec lacks, the spec is extended (A20), not the design cut.

- **a. Screen count.** Spec says 24; the design file has 36. Screens 25–36 (reset, deletion, export, import, timer states) are covered by the API. Update the spec count.
- **b. Profile photo and location.** Adopted as designed. Specified in A20 (photo pipeline, location fields, profile mutations).
- **c. MVP vs advanced.** Today (05) shows the XP/Level chip while the MVP excludes XP. The chip is built with the screen but stays behind a `rewards_enabled` flag until Phase 5, so it never shows numbers the server cannot yet confirm.
- **d. Contrast.** By my calculation `infoInk #318297` on `infoBg #E1F2F6` is ≈ 3.8 : 1 (≈ 4.4 : 1 on white) — below the file's own 4.5 : 1 body-text rule. Recommended (Khay Studios decides; this changes a token value, not a screen): darken `infoInk` to `#256E82` (≈ 5.0 : 1 on `infoBg`). `progress #5CAC60` on white is ≈ 2.8 : 1: acceptable only because values are always also printed as text; never use it as the sole indicator. Run a contrast tool over every token pair before building themes.
- **e. Dark tokens.** The dark values are exported without labels. Map them by order to the 21 light roles: canvas, background, surface, ink, muted, border, primary, pressed, onPrimary, positiveBg, positiveInk, infoBg, infoInk, warningBg, warningInk, errorBg, errorInk, disabledBg, disabledInk, progress, focus. Verify against Figma variables.

---

## 5. Environment and delivery

### A15 — Password reset needs a domain and app links · ADOPT (Phase 6)

The email link opens screen 27, which needs an HTTPS domain, `/.well-known/assetlinks.json` (Android), `apple-app-site-association` (iOS) and a web fallback route. Build the rest of auth first.

### A17 — Platform constraints · ADOPT

- **Android**: schedule reminders inexact (do not request `SCHEDULE_EXACT_ALARM`; unnecessary and Play-policy friction); request `POST_NOTIFICATIONS` (Android 13+); reschedule on boot; show battery-optimisation guidance; test on at least one aggressive-OEM device (Xiaomi, Tecno/Infinix, Samsung sleeping apps).
- **iOS**: at most 64 pending local notifications → rolling horizon (next 7–14 days, capped), rebuilt on app open and background refresh.
- **Windows dev machine**: iOS cannot be built locally. Android first; iOS builds and real-iPhone gates go through a macOS CI runner or cloud Mac service when you reach them.

### A18 — Migration order and conventions · ADOPT

Spec order puts reminders/devices before the sync tables; the MVP needs the sync spine earlier.

1. users + timezone history + tokens
2. habits / definition versions / active ranges
3. logs + streak cache + period_evaluations
4. mutation_receipts + server_changes (+ `users.change_seq`)
5. reminders + devices
6. XP entitlements / ledger
7. freeze ledger / usage / policy versions
8. export / import / push jobs

CHECK constraints (balance 0–2, xp ≥ 0, target > 0, …) via `DB::statement` in the same migration; `jsonb` for JSON; UUIDv7 primary keys (Laravel `HasUuids`, Dart `uuid` v7 for offline-created ids) for B-tree locality.

### A19 — Laravel 13 instead of 12 · CONFIRMED 2026-10-06 (Laravel 13)

Laravel 12's bug-fix window closed on 13 Aug 2026 (security fixes until 24 Feb 2027). Laravel 13 is the current major and requires PHP ≥ 8.3; the dev machine runs 8.4. Nothing in the spec depends on 12-specific behaviour, and a greenfield build should not start on a security-only release.

---

## 6. Added after Khay Studios review (2026-10-06)

### A20 — Profile photo, location and profile mutations · ADOPT

Adopts Profile (screen 20) as designed: photo avatar (sizes 24/40/80) and a "City, Country" line. Initials avatar when there is no photo.

**Schema (`users`)**: `city varchar(60) null`; `country_code char(2) null` (ISO 3166-1 alpha-2, CHECK `^[A-Z]{2}$`); `avatar_key text null`; `avatar_version int not null default 0`; `avatar_sha256 char(64) null`; `version bigint not null default 1` (profile concurrency). Location is a typed or picked label only: never GPS, never auto-detected, never geocoded. Display only for now (regional defaults later).

**Profile edits are mutations (A14)**: add `profile.update {name, city, country_code}` (version-checked against `users.version`) and `profile.set_timezone` (future-effective, validated IANA). `PATCH /me` stays as the REST adapter. The `user` entity in the journal carries name, city, country_code, avatar_version, the A9 reward fields and freeze balance.

Clarification (2026-10-10, 3b.1 review): there is no PATCH /me; profile changes go through /sync (A14) and the photo through the avatar endpoints; the user entity also carries has_avatar.

**Photo upload (binary, so not a journal mutation)**
- `PUT /api/v1/me/avatar` (multipart, `Idempotency-Key`), `DELETE /api/v1/me/avatar`, `GET /api/v1/me/avatar/{sm|md|lg}`. Authenticated and owner-only; `Cache-Control: private`; ETag = `avatar_sha256`. No public URLs (matches "private by default, no public profile").
- Pipeline: validate by file content (finfo), not extension; cap upload at 5 MB and decoded size at 25 megapixels before decoding; decode, strip all metadata (EXIF/GPS), re-encode (WebP or JPEG) as 96 / 160 / 320 px squares; discard the original; never serve user bytes unprocessed. Store in the private object store at `avatars/{user_id}/{uuid}.webp`; delete the previous object on replace.
- Success bumps `avatar_version` and emits a `user` journal change; other devices notice the new version and fetch lazily.
- Rate limit: 10 uploads per hour per user.
- Account deletion purges avatar objects (add to the purge job). The export package includes the avatar as a separate file; import restores it through the same pipeline.

**App**: `image_picker` (Android photo picker needs no storage permission; iOS needs camera/photo usage strings) + `image_cropper` (square). The chosen photo shows immediately from local storage; the upload waits in a durable `pending_uploads` drift table with the outbox's retry/backoff rules and is never dropped until acknowledged. Alt text: "Profile photo of {name}".

**Release**: declare photos as collected data in the store data-safety and privacy forms.

### A21 — Habit type registry and tolerant reader · ADOPT

Prerequisite for adding habit types without a rewrite each time. Details in `docs/EXPANSION_PLAN.md` §2.
- A `HabitType` strategy (api) and a type-widget registry (app) own: value schema and validation, allowed log operations, completion predicate, evaluation timing (immediate vs at period close), XP eligibility, insights aggregation and UI components. No `switch` on type anywhere else.
- `habits.type` becomes `varchar(24)` validated by the registry (not a DB enum or CHECK list). Definition versions gain `config jsonb` (type-specific, e.g. checklist item ids). Logs gain `detail jsonb` (type-specific state) and `note text null` (universal; app-layer encrypted).
- `value` stays the scalar the rule evaluates (checklist = items done, rating = the rating, time-of-day = seconds since local day start).
- The wire protocol stays small and generic: `log.set_value {value, detail}`, `log.increment {delta}`, `log.set_item {item_id, done}`, `log.set_note {note}`. New types reuse these.
- **Tolerant reader**: the app preserves unknown habit types, operations, entity fields and statuses as opaque data, shows a read-only "Update the app to see this habit" card, never drops or crashes, and keeps syncing. The server rejects an operation a habit's type does not support with 422 `unsupported_operation`, and rejects creating a type the client has not declared (`X-App-Version` + `X-Capabilities` headers). Additive changes (new types, fields, operations) do not bump `/v1`.

### A22 — Day-start offset · ADOPT (engine now, UI later)

Night-shift and night-owl users log at 00:30 for "today". Make the day boundary a parameter now: store `day_start_offset_minutes` (0–360, default 0) in the same effective-dated calendar history as the timezone, resolved at `occurred_at`. `DayResolver`, `PeriodEngine` and closure use it; logs freeze it alongside `resolved_timezone`. No UI until a later phase. Retrofitting after dates are stored is expensive; adding it as a defaulted parameter in Phase 1 is nearly free.

### A23 — Retention foundations · ADOPT

Supports `docs/EXPANSION_PLAN.md` sections 6 and 6b. Laying these now avoids retrofits.
- **`LocalMutationService`** (app, pure Dart, no `BuildContext`): the only way the app writes domain data locally. Writes projection + outbox in one drift transaction (invariant 8). Called by the UI, notification actions, widgets and background sync.
- **Multi-isolate database**: Phase 0 includes a spike proving one drift approach that lets the UI isolate, the background-sync isolate and notification-action callbacks open the same account database safely. The chosen approach is documented in the repo.
- **Notification action schema**: `log:{habit_id}:{operation}:{value}` plus `slot` (local date + reminder id). Handlers call `LocalMutationService` and are idempotent per slot.
- **`habit.pause {until_date}`**: ends the current active range today and inserts a range starting on `until_date`. The half-open, non-overlapping model supports a future `starts_on`; add a test. No history rewrite; no eligibility before the new `starts_on`.
- **`weekly_reviews`** entity + `review.set_reflection` mutation (Phase 8): `id uuid, user_id, week_start DATE (Monday), reflection text (app-layer encrypted), version`; unique `(user_id, week_start)`.
- **Widget snapshot**: the app writes a small JSON snapshot for widgets; widgets never read the database directly.

---

## 7. Added after the Phase 0 review (2026-10-07)

Decisions from the architect's Phase 0 review (`docs/reviews/PHASE_0_REVIEW.md`).

### A24 — Toolchain versions · ADOPT

- **Flutter 3.47.x stable** replaces the spec's 3.44.x (the spec asked to confirm versions during implementation). Pinned in `app/pubspec.yaml` (`environment: flutter`) and in CI.
- **PHP 8.4**: Composer's `config.platform.php` is `8.4.1` so dependency resolution never drifts to a newer local PHP. (`8.4.1`, not `8.4.0`, because `symfony/http-foundation` 8.1 requires ≥ 8.4.1.)
- PostgreSQL 17 in CI and Docker (spec floor stays 16).

### A25 — Error envelope and codes · ADOPT

- Error `meta` carries **both** `request_id` and `server_time` (spec 06: "all responses carry request_id and server_time"). Success `meta` also carries `api_version`.
- Error codes are contract, listed in `docs/api-error-codes.md` with one golden fixture each. Approved set: `bad_request`, `unauthenticated`, `forbidden`, `not_found`, `method_not_allowed`, `version_conflict`, `idempotency_mismatch`, `resource_deleted`, `cursor_expired`, `payload_too_large`, `unsupported_media_type`, `validation_failed`, `rate_limited`, `http_error`, `server_error`, `unavailable`. Reserved for later phases: `timezone_context_mismatch`, `dependency_pending`, `unsupported_operation`, `unsupported_type`.
- `resource_deleted` carries `entity`, `resource_id` and `current_version` (the tombstone version).
- In `/sync`, per-mutation failures are not HTTP statuses: the ack's `error` object reuses exactly these shapes.
- Rate limits: defaults are environment-configurable; keyed by user id when authenticated, IP otherwise.

---

## 8. Added after the Phase 1 review (2026-10-07)

Decisions from the architect's Phase 1 review (`docs/reviews/PHASE_1_REVIEW.md`).

### A26 — Calendar changes and day boundaries · ADOPT

- Invariant: **an event's date never goes backwards.** An event's date uses the calendar entry in force at `occurred_at`; a date's start uses the latest entry effective at or before that start. A day that began under the old zone ends at the next local midnight in the zone then in force, so a travel day can run long (westward) or short (eastward).
- `profile.set_timezone` (and any calendar change, including `day_start_offset`) creates its entry **effective at the user's next local day start in the old calendar**, never at an arbitrary instant.
- The first calendar entry governs instants before it (still bounded by the 90-day offline rule). `no_calendar` is only for an empty history.
- Day start: the first instant whose wall clock shows `00:00 + day_start_offset`; inside a DST gap, the transition instant. Only `TimezoneTimeline` and `PeriodEngine::bounds()` compute day and period instants.

### A27 — Wire operation names · ADOPT

- Canonical log operations are A21's: `log.set_value`, `log.increment`, `log.set_item`, `log.set_note`. `HabitType::operations()` lists canonical names only; receipts store the canonical name; the app sends canonical names only.
- The spec's names are accepted as aliases for the built-in types only, normalised in one place before validation: `log.set_binary` → `log.set_value` (binary), `log.increment_quantity` → `log.increment` (quantity), `log.increment_duration` → `log.increment` (duration, seconds). An alias on the wrong type is 422 `unsupported_operation`. Remove the aliases before the first public release if nothing uses them.

### A28 — Phase 1 domain rules · ADOPT

- **Partial weeks:** a `weekly_count` week is due only if the habit is active on at least `count` of its days; the definition in force on the week's first active day governs it.
- A habit-day holds at most 25 hours (the fall-back day).
- An insights window owns the periods whose start date falls inside it.
- Freeze opt-in is decided by the policy in force at the period's `ends_at`.
- A monthly grant at the cap writes a zero-delta `cap_reached` row so the month is marked done.
- Increments are greater than zero. Percentages round half up with integer arithmetic only.
- `HabitType` operates on a `LogState` (`value` + `detail`) and the effective `DefinitionVersion` (with `config`), so non-scalar types (checklist) need no engine change (A21).
- Domain errors map to API codes in one place: `future_event`, `event_too_old`, `timezone_context_mismatch`, `backdate_future`, `backdate_too_old`, `unsupported_type`, `unsupported_operation`, `invalid_value` (`docs/api-error-codes.md`).

---

## 9. Added after the Phase 2a review (2026-10-07)

Decisions from the architect's Phase 2a review (`docs/reviews/PHASE_2A_REVIEW.md`).

### A29 — Sync contract hardening · ADOPT

- **Restore.** `log.set_value` with `base_version` equal to a tombstone's version restores that row: `deleted_at` cleared, `version + 1`, journaled as an upsert. A lower `base_version` (an edit queued before the delete) still returns `resource_deleted`, so nothing is silently resurrected (spec 07).
- **Canonical ids.** Every ack carries the server's canonical `entity_id`, which can differ from the mutation's (the server keeps the existing row for `(habit_id, log_date)` and never reuses a client id that exists elsewhere). The client remaps the local row and every outbox row referencing it in one transaction.
- **Natural-key delete.** `log.delete` falls back to `payload.habit_id` + `payload.log_date` when the entity id is unknown to the server.
- **Server errors.** An unexpected failure inside one mutation is reported and returned as a `rejected` ack with `error.code = server_error` and `error.retryable = true`; no receipt is stored, so a later retry (or deploy) can accept it. The rest of the batch is unaffected.
- **Cursors.** Any cursor that cannot be honoured (bad signature, other user, ahead of the journal head, older than retention) is 410 `cursor_expired`, for both `/sync` and `/sync/bootstrap`; the client bootstraps. 422 is only for a malformed `cursor` parameter.
- **Capabilities.** A request without `X-Capabilities` declares the baseline set of spec v1's three types: `type.binary, type.quantity, type.duration` (corrected in the Phase 2a.1 review).
- **Timezone context.** A `captured_timezone` that differs from the server's calendar at `occurred_at` is accepted when `local_date_hint` equals the server-resolved date (the server still resolves the date). Otherwise `timezone_context_mismatch`, with the server's calendar entry for that instant in `error.calendar`.
- **Caps.** One mutation is at most 16 KB of JSON and 8 levels deep (`payload_too_large` / `validation_failed` in its ack). Values are range- and scale-checked per type; `frequency_config` is stored in canonical form; units are validated per type.
- **Auth.** Refresh shortens the old token to a 10-minute grace window instead of deleting it. Login always runs a password hash check, including for unknown emails.

### A30 — Calendar gaps and frequency boundaries · ADOPT (Phase 3)

- **Zero-length dates.** A local date with no instants (eastward travel across the date line, e.g. Pago_Pago → Auckland on 2026-03-11; Pacific/Apia 2011-12-30) is not part of the period grid: not due, not evaluated, and it neither breaks nor extends a streak.
- **`nextEffectiveDate`** is the next Monday when either the old or the new frequency is `weekly_count`, so a frequency change never leaves days outside every period.

## 10. Added after the Phase 2b.1 review (2026-10-07)

Decisions from the architect's Phase 2b.1 review (`docs/reviews/PHASE_2B1_REVIEW.md`).

### A31 — New entity types in bootstrap · ADOPT

- **One array.** `GET /sync/bootstrap` carries entity types added after v1 in one top-level array, `entities: [{entity, id, version, payload}]`, using the same singular entity names as `/sync` changes (`habit_log`, not `logs`). The three v1 collections (`user`, `habits`, `logs`) are unchanged.
- **Client.** An app that does not know an `entity` stores the item in `opaque_entities` under that name, so a bootstrap and a later pull keep one entity under one name. Any other unknown top-level list is still kept, under type `bootstrap:<key>`; nothing is dropped (invariant 13).
- **Undecodable items.** A change, bootstrap item or ack this app version cannot decode is stored raw as `undecodable:<entity>` and the cursor still advances (review F2).
- **Server.** No server work until the first new entity type exists.

## 11. Added after the Phase 2b.2 review (2026-10-08)

Decisions from the architect's Phase 2b.2 review (`docs/reviews/PHASE_2B2_REVIEW.md`).

### A32 — Derived entities · ADOPT

The client never evaluates streaks (invariant 9), but screens must work offline, so the server sends results as sync entities, journaled in the SAME transaction that computes them (invariant 6). Both are READ-ONLY for clients: a mutation targeting them is rejected with code `entity_read_only`.

- **`habit_progress`**: id = the habit id. Payload `{habit_id, current, longest, unit, computed_through}`. Version = the streak cache's `version`. Deliberately NOT part of the `habit` entity: bumping a habit's version on every log would cause false conflicts against definition edits.
- **`period_evaluation`**: id = the `period_evaluations` row id. Payload `{id, habit_id, period_key, start_date, end_date, completed, protected, definition_version, timezone, revision}`. Version = revision. Journaled when a period closes and again when a late offline log changes the result.
- **Bootstrap** carries both through A31's `entities` array (its first real use): `habit_progress` for every non-deleted habit; `period_evaluation` limited to the last 400 days. Older history comes from `GET /habits/{id}/heatmap` when online.
- **Habit delete** journals a delete for its `habit_progress` in the same transaction. Its evaluations stay on the server (needed for restore) and are not sent in bootstrap for deleted habits. A restore brings them back.
- **Not-due days are not stored.** The Dart port of due-ness (`HabitSchedule`) comes in 3.2 and is pinned by the same fixtures as PHP.

## 12. Added after the Phase 3.2c review (2026-10-10)

### A33 — Legal documents and consent record · ADOPT

Terms of Service and Privacy Policy are public pages built from `docs/legal/*.md` (front matter `title`, `version` YYYY-MM-DD, `effective` YYYY-MM-DD, `status` draft|final) and `docs/legal/facts.json`. `POST /auth/register` requires `terms_version` and `privacy_version` (strings YYYY-MM-DD that are real dates). Stored on `users`: `terms_version char(10) null`, `privacy_version char(10) null`, `legal_accepted_at timestamptz null` (server clock); null only for accounts created before A33. Not part of the user sync entity and not returned by any endpoint (the export will include them in Phase 6). Re-consent after a material change is Phase 7; archive of past versions is git history.

## 13. Added after the Phase 3b review (2026-10-10)

### A34 — Editing, archiving and restoring habits · ADOPT
- Operations on entity `habit`, applied by the one MutationApplier and journaled: `habit.update`, `habit.archive`, `habit.restore`. Each requires `base_version` = `habits.version`; a stale one is 409 `version_conflict` with the canonical habit as `current`. There is no habit delete in v1 (the spec has none, no screen shows one; the only hard delete is account deletion, Phase 6, and A32's habit-delete clause applies there). *Superseded by A51 (2026-10-25): a habit can be deleted.*
- `habit.update` payload is the whole desired editable state: `{name, category, target_value, unit, frequency_type, frequency_config}`. `type` is immutable (A4): if sent it must equal the habit's type, else 422 `invalid_value`. A desired state identical to the current one is acknowledged with no version bump and no journal row (like `profile.update`).
- The name lives on the habit and applies at once. Category, target, unit and frequency are a definition change: a new `habit_definition_versions` row (next version number) effective from `HabitSchedule::nextEffectiveDate`, computed from the user's local date at APPLY time (server clock plus the user's calendar), never from a client date or `occurred_at`. If the latest version has not taken effect yet (its effective date is after today) it is replaced in place by the new desired state; if the desired state equals the version in force, the pending version is removed. Past check-ins and closed periods keep their definition (A4).
- The habit's top-level fields stay the projection of the LATEST definition version; clients derive what governs a date from `definitions`.
- `nextEffectiveDate`: daily/weekdays: tomorrow; weekly_count (old or new): next Monday (A30); interval (old definition): the first day after today on which a period of the OLD definition starts.
- `habit.archive` sets `archived_at` and closes the open active range at the start of the NEXT local day (today's check-ins stay valid). Already archived: acknowledged, no bump. While archived, `habit.update` and every `log.*` write on the habit are rejected 422 `habit_archived`.
- `habit.restore` clears `archived_at` and opens a new active range starting at max(today, end of the previous range); earlier gaps stay excluded. Not archived: acknowledged, no bump.
- Reminders are untouched on the server; the app stops scheduling an archived habit's reminders.
- v1 keeps type-based habit icons: no `icon` field, no picker (no design for one). Reopen with the Tier-1 design drop (4b).

### A35 — Log increments · ADOPT
- `log.increment {habit_id, delta, date_mode?, log_date?}` on entity `habit_log` (aliases per A27). Atomic additive merge: no `base_version`, the receipt applies it once, concurrent increments commute and none is lost. `delta` > 0: a decimal string (quantity, up to 3 decimals) or whole seconds (duration), validated by the type. It creates the day's log if absent. Date resolution, backdate limits and the active-range check are those of `log.set_value`.
- On a deleted day (tombstone): 409 `resource_deleted` with the tombstone as `current`. On an archived habit: 422 `habit_archived`. On a type without the operation: 422 `unsupported_operation`.
- XP and level effects of a threshold crossing are Phase 5; Phase 4 only sums.

### A36 — Timer drafts · ADOPT (client only, no API change)
A timer for a duration habit is a local draft, never synced. Table `timer_drafts`: `habit_id` TEXT primary key, `state` TEXT (`running` or `paused`), `elapsed_ms` INTEGER (time banked while not running), `running_since` INTEGER nullable (UTC epoch ms of the last start or resume; null when paused), `created_at` INTEGER, `updated_at` INTEGER. One draft per habit; per-account database. Elapsed = `elapsed_ms` + max(0, now - `running_since`) while running, so a clock set backwards never shrinks it. Only a habit whose type rules say it supports a timer (display duration) can have one. Finish: whole seconds = floor(elapsed / 1000); zero deletes the draft and writes nothing; otherwise, in ONE transaction, the draft is deleted and a `log.increment {habit_id, delta: seconds}` is queued, filed under the habit-day of the finish moment (the server resolves it from `occurred_at`). More than one day can hold (`DurationRules.maxSeconds`) is a typed failure and the draft stays. Drafts never enter the outbox and never leave the device. Pausing is allowed on an archived habit; starting, resuming and finishing are not.

### A37 — Resolving a needs_attention row · ADOPT (client only, no API change)
Allowed only for rows in `needs_attention` whose `lastError` code is `version_conflict`, `resource_deleted` or `habit_archived`; any other code can only be discarded. The row's `lastError` keeps the server's `current`. KEEP SYNCED: the existing discard (the row moves to `discarded_mutations`, nothing is sent). USE MINE: in one transaction the old row moves to `discarded_mutations` and a NEW mutation is queued (new id, because the server keeps a receipt for the old one) with the same entity, operation and payload, the original `occurred_at` (never now), state pending, no error, and `base_version` = `current.version` taken from `lastError`. Exceptions: (1) a `log.increment` refused with `resource_deleted` becomes a `log.set_value {habit_id, value: the delta, date fields kept}` on the tombstone's version (an explicit restore, A29); (2) for `habit_archived`, use-mine is allowed only once the habit shows active on this device; it keeps the row's own `base_version`. A second conflict returns the new row to `needs_attention` with a new `lastError` and the person reviews it again. The new mutation keeps the old row's place in the queue, except that a use-mine for habit_archived goes after the habit's queued restore.

### A38 — Reminder presentation on Android · ADOPT (client only, no API change)
Reminders use the Android notification channel `reminders_alert` at high importance, so a reminder pops up as a banner as well as staying in the tray; the person can lower it in the system settings. The old channel `reminders` is deleted at start. The channel is part of each scheduled reminder's content key, so changing it replans every pending reminder onto the new channel (replaced, never duplicated). A replan never cancels a reminder whose time has passed: only its record is dropped, so it stays in the tray until the person clears it, also after Hide habit names is switched on or the habit is done. Wording stays neutral (invariant 12). iOS shows reminders by its own settings.

## 14. Added after the Phase 4.3c review (2026-10-12)

### A39 — reward_state is its own derived entity (amends A9) · ADOPT
XP and the freeze balance change on every check-in, so they cannot live on the user entity: each change would bump `users.version` and make every queued `profile.update`, `profile.set_timezone` or `profile.set_auto_freeze` conflict. New read-only derived entity (A32 rules; a mutation targeting it is rejected with `entity_read_only`): `reward_state`, id = the user id, payload `{xp, level, progress_into_level, next_level_threshold, freeze_balance}`, version = `users.reward_version`. `reward_version` rises by one in the same transaction as every `xp_ledger` or `freeze_ledger` row that changes a cached number (a zero-delta audit row does not bump it). The change is journaled in that transaction (invariant 6) and the entity is bootstrapped through A31's entities array. The user entity and GET /me stop carrying `xp`, `level`, `progress_into_level`, `next_level_threshold` and `freeze_balance` and keep `auto_freeze`. GET /rewards and GET /freezes carry the same numbers with their ledgers. Otherwise A9 stands: the client never evaluates the formula.

### A40 — XP on the server · ADOPT (the not-due-day default confirmed by Khay Studios on 2026-10-12)
One entitlement per (habit, log_date), never deleted. Ledger rows are +10 completion, -10 reversal and +10 recompletion (`XpRules::transition`); `users.xp` is their sum and never below 0. The award runs inside the check-in mutation's transaction, under the user lock, for `log.set_value`, `log.increment` and `log.delete`, and whenever a late or edited log changes whether a past day is complete. The date is the log's date (backdates included). Partial progress and increments after completion earn nothing; archive and restore earn nothing. A first award needs the write to change the day from not complete to complete, so a day that was already complete before Phase 5 earns nothing until its completion changes. A day that is not due earns XP like any other and never affects a streak. Replaying a mutation id awards nothing twice.

### A41 — Freeze wallet · ADOPT
Signup grant: in the registration transaction a grant row with source_key `signup` tops the balance to 2 (this replaces ASSUMPTION(A2a-signup-grant) in AccountService). Monthly grant: `PeriodCloser::closeUser`, under the user lock, writes source_key `month:YYYY-MM` for the user's local month, UNIQUE(user_id, source_key). It credits 2 minus the balance, or writes a zero-delta `cap_reached` row when the wallet is full, so a retry or a concurrent job credits once. Accounts that existed before Phase 5 have balance 0 and no ledger; their first close tops them up to 2 (reason monthly). Opt-in never gates grants (A11). Spend: when periods close, every newly closed failed period of every frequency type is a candidate. One decision pass per user across all habits (`FreezeEvaluator::closePeriods`, order from A8); one token per failed period (a failed week costs one, not seven); only while the user's policy in force at the period's ends_at is enabled; never for an open period; at most one usage per (habit, period_key). "Newly closed" is decided by `users.freeze_closed_through`: a period is offered to the wallet when it ended after the watermark, and the watermark moves to yesterday after each pass. A miss that closes with an empty wallet is never rescued by a later grant. A pass that spans several days counts each habit's streak at risk without the protections the same pass grants, so across habits the A8 order can differ from a day-by-day pass (known, rare: the closer runs every 5 minutes). A spend writes a `freeze_usage` row (active) and a spend ledger row, sets the period evaluation to protected = true (revision up, journaled) and recomputes that habit's streak in the same transaction. Late completion: when a late or edited log makes a protected period complete, the usage becomes refunded, the evaluation becomes completed and not protected, and one refund row credits min(1, 2 - balance); at the cap the row is written with delta 0 and reason `cap_reached` (the audit). A refunded usage never reactivates: undoing that check-in later does not spend again. `habit_progress` gains `protected_in_streak` (the number of protected periods inside the current streak) so the app needs no heuristic; its version rises when the value changes (A32). Weekly: the closer stores closed weekly_count periods as period_evaluation entities like daily ones (A10, A30), because tokens are spent on them; if interval periods are not stored either, store them the same way and say so in the packet.

### A42 — Auto-freeze is a mutation · ADOPT
`profile.set_auto_freeze {enabled}` on entity user, base_version required, applied by the MutationApplier (A14). An identical state is acknowledged with no version bump and no policy row. Otherwise `users.auto_freeze` and `users.version` change and one `user_freeze_policy_versions` row is written with effective_at = the server clock at apply (never occurred_at, so opt-in is prospective); the user entity is journaled. The spec's PATCH /me/settings is not built (A14: /sync is the only write route). GET /rewards and GET /freezes are read-only.

## 15. Added after the Phase 5.1 review (2026-10-12)

### A43 — What the app needs from the server for rewards · ADOPT
An accepted ack for log.set_value, log.increment or log.delete carries `xp_delta` (an integer, +10 or -10) when that mutation moved XP, and no `xp_delta` key otherwise. It is stored in the receipt, so a duplicate replay returns the same ack with the same `xp_delta`. GET /freezes gains `next_refill_on`: the first day of the user's next local month (YYYY-MM-DD, from their calendar). The app never infers an award from totals and never computes a refill date. Old apps ignore both (A21).

### A44 — Reward display on the app · ADOPT (amends A9)
The app shows xp, level and freeze balance exactly as `reward_state` last confirmed them, never an amount it computed. A9's "+10 pending" becomes words only: while changes wait to sync, the screen says "Rewards update after syncing." The bar on 16 and 35 fills progress_into_level divided by span, where span = next_level_threshold minus (xp minus progress_into_level), clamped to 0..1, and empty when span is 0 or less. The label reads '{progress_into_level} / {span} XP toward Level {level + 1}'. This is display arithmetic on the confirmed numbers, kept in one tested function (LevelProgress); it is not a rule. If levels ever skip, the server must send the next level. Completion screens (06 duration, 35 quantity, one layout) appear only for an accepted ack with `xp_delta` above 0, reached from the save screen after the local write, never before; offline, timed out, a conflict or no `xp_delta`: the save returns as it does today.

## 16. Added after the Phase 5.2a review (2026-10-17)

### A45 — Auto-freeze rebases once · ADOPT
profile.set_auto_freeze is a desired state, so a version_conflict on it is handled like one on profile.set_timezone: the engine re-sends it once, as a new mutation, on the version the server names. The user entity's version also moves for reasons the person did not cause (another device, a photo, a time zone change). A second conflict is the user's to see, and the only choice is Discard.

### A46 — Completion flow · ADOPT
A completion screen (35 quantity, 06 duration, one layout) opens only for a check-in saved from the amount screen or the timer's save that left the habit-day complete on this device. After the local write the app asks for a sync at once and waits up to 6 seconds for the ack of that mutation. Offline, a timeout, a conflict or rejection, an ack without xp_delta above 0, or the person leaving the screen: the save returns as it does today, and a late ack never opens the screen afterwards. The +N XP chip shows the ack's xp_delta, never a constant. A one-tap check-in on Today, an undo and a delete never open it. The Level card reads the local reward_state live.

## 17. Added after the Phase 5.2c review (2026-10-21)

### A47 — GET /insights · ADOPT
`GET /insights?period=week|month[&category=…]`, auth:sanctum and throttle:api, read-only (A14). `period` is required; `category` is one of the habit categories; any other parameter, a missing or unknown period or an unknown category is 422 `validation_failed` with the field named. The window is the user's local week (Monday to Sunday) or calendar month that contains their local today at request time, from their calendar history (A22); there is no date parameter. The lazy closer runs first (A10).

Response `data`: `period`; `category` (the filter, or null); `window` {`start`, `end`, `today`, `through`} where `through` is the last closed local date (yesterday) or null when it falls before `start`; `totals` {`completed`, `eligible`, `percent`}; `xp_earned`; `by_category`, one {`category`, `completed`, `eligible`, `percent`} per category with eligible > 0, in `DefinitionVersion::CATEGORIES` order, summing to `totals`. Week only: `days`, seven {`date`, `completed`, `due`, `open`} where `due` and `completed` count the day periods (daily, weekdays, interval) due and completed that local day, `open` is true for today and future days carry null counts; and `open_periods`, one {`habit_id`, `completed`, `target`} per weekly habit whose current week is still open. Month responses omit `days` and `open_periods`. No habit names travel.

Rules: consistency counts closed eligible periods only; a period belongs to the window containing its start date (A28); open, future and not-due periods and archived habits (`archived_at` set) are excluded; protected periods count in the denominator, never the numerator. Periods come from the PeriodEngine the closer stores from, with the habit's active freeze usages; a closed period takes its status from its stored evaluation. A period's category is that of the definition in force for it. Counts and `percent` (half up, null when nothing is eligible) come from `ConsistencyCalculator`. `xp_earned` is the XP actually given (amended after the 5.3a review): 10 per active XP entitlement whose log_date is between the window's start and `through` inclusive, 0 when `through` is null; today is never counted, not-due check-ins and the days of a still-open weekly period count, archived habits keep their XP, and a category filter counts only habit-days whose definition in force on that date has that category. The app shows what the server sent and computes none of it; it keeps the last answer per period in memory for the session only.

## 18. Added after the Phase 5.3b review (2026-10-24)

### A48 — Exports · ADOPT
`export_jobs`: id (UUIDv7), user_id, format (`json` | `csv`), status (`queued` | `running` | `ready` | `failed` | `expired`), snapshot_seq, object_key, expires_at, error_code, created_at, updated_at; CHECK constraints on format and status in the migration; index (user_id, created_at).

- `POST /exports {format}` → 202 with the job. When the user already has a queued or running job of that format, that job is returned (202) instead of a new one. Throttle: 6 requests per hour per user. An export is not a domain write: no journal row, nothing through `/sync`.
- `GET /exports` → the user's 5 newest jobs, newest first (the one route added to the spec's list, so screen 21 shows "Latest export" on any device). `GET /exports/{id}` → one job. A ready job carries `download_url` and `expires_at`. Another user's id, or a missing one, is 404 `not_found` with no detail.
- `GET /exports/{id}/download`: a temporary signed URL that also requires `auth:sanctum` and the owner. It streams the object with `Cache-Control: private, no-store`. Order of checks: session (401), owner (404), expiry (410 `export_expired` once `expires_at` has passed or the job is expired), signature (403 `forbidden` when tampered).
- A link lasts 24 h from ready. A scheduled command marks ready jobs past `expires_at` as expired and deletes their objects.
- Storage: a private disk under `exports/{user_id}/{uuid}.{zip|csv}`, through an `ExportStore` that refuses any key outside the caller's folder (as `AvatarStore` does). Encryption at rest is the storage service's job (the production object store with server-side encryption on), not the app's.
- A job runs in one REPEATABLE READ snapshot; snapshot_seq is `users.change_seq` read inside it. JSON is a zip of `export.json` (schema_version, generated_at UTC, snapshot_seq, profile name, email, city and country_code, timezone history, habits with definition versions and active ranges, live logs with local dates, reminders, XP entitlements and ledger, freeze ledger, usages and policy versions), `manifest.json` (schema_version, user_id, snapshot_seq, generated_at, files with name and sha256, kid, signature: HMAC-SHA256 over the canonical JSON of the manifest without `signature`, A16) and `avatar.webp` when there is a photo (A20). CSV is one `checkins.csv`: local date, habit id, habit name, category, type, value (decimal string; durations in whole seconds), unit, target in force, completed (the server's rule), note. Every user-controlled cell is neutralised (A16: a cell starting with `=`, `+`, `-`, `@`, tab or carriage return gets a leading `'`).
- Canonical JSON: object keys sorted at every level, no whitespace, UTF-8 unescaped, integers as integers, strings as JSON strings. Signing keys come from config (`EXPORT_SIGNING_KEYS` as `kid:secret` pairs, `EXPORT_SIGNING_KID` the current one); none is in the repository.
- Never in an export: password hashes, tokens, push tokens, reset tokens, device ids, diagnostics.
- Failure: the job becomes failed with an `error_code`, any partial object is deleted, and history is never changed. A retry is a new POST.
- The app downloads with its bearer token into a temporary file and hands it to the system share sheet (`share_plus`) so the person chooses where to keep it; the temporary file is then deleted. No export data is stored in the app's database.

## 19. Added after the Phase 6.1 review (2026-10-25)

### A49 — Account deletion · ADOPT
`account_deletions`: id (UUIDv7), user_id (nullable, set null once purged), status (`queued` | `purging` | `completed`), requested_at, purge_after, completed_at, receipt_hash (SHA-256 hex, unique), receipt_expires_at, created_at, updated_at; CHECK constraints on status and on completed ⇔ completed_at in the migration.

- `DELETE /me {password}` → 202. Recent reauthentication is the password in the request, checked against the hash. A wrong password is 422 `validation_failed` on `password`; a missing one is 422 too. Throttle `account-delete`: the login limits, per IP and per user. In one transaction under the user-row lock: `users.deleted_at` set; every Sanctum token of the user deleted (the app has no separate devices table: a device is its token row, so this revokes every device); an `account_deletions` row created with `purge_after = requested_at`; a receipt issued. The purge job is dispatched after commit.
- The 202 body: `{ id, status, requested_at, completed_at, receipt_token, receipt_expires_at }`. `receipt_token` is a random secret returned once and stored only as its SHA-256 hash. It is valid 35 days and reads `GET /account-deletions/{id}` and nothing else.
- `GET /account-deletions/{id}` takes the receipt as `Authorization: Bearer`. It returns `{ id, status, requested_at, completed_at }` only. Any other id, a wrong, expired or missing receipt, or a full session token is 404 with no detail. Every other route answers a receipt with 401, because it is not a session.
- After the request: login with that email fails exactly as a wrong password does (same message, same hashing work). Register with that email is 422 `validation_failed` on `email`, the same answer an existing account gets, until the purge completes. Old tokens and every other route answer 401. A writer already past authentication that takes the user lock after the deletion committed gets 401 (`ChangeJournal::lockUser` re-checks `deleted_at`); one that committed first is purged with the rest.
- Purge job (queued; also picked up by a scheduled command for any deletion past `purge_after` that is not completed; the 30 days are an upper bound, not a delay): marks the deletion `purging`; deletes the user's export and avatar objects by owner prefix (A20, A48), which is idempotent; then, in one transaction under the user lock, deletes every owned row in dependency order: rows under the user's habits (definition versions, active ranges, streak cache, period evaluations, reminders, logs, freeze usage, XP entitlements and ledger), the habits, mutation receipts, server_changes, freeze ledger, freeze policy versions, timezone history, export jobs, tokens, then the users row. It sets the deletion `completed` with `completed_at` and `user_id` null in the same transaction. A failure rolls the transaction back whole; the job and the scheduled command retry it. Import rows join the purge when imports exist (Phase 6.3).
- Nothing about the deleted person is logged beyond ids.
- The app: on 202 it stores the receipt token and deletion id in secure storage under a device-level key (it outlives the account); closes and deletes that account's database file and secure tokens; cancels its reminders and background sync; and opens sign in with "Your account is being deleted. Sessions on your other devices have ended." Other accounts on the device are untouched. Other devices of the account get 401 and sign out as an expired session does.
- Retention: privacy.md section 7 already says sessions end at once, data leaves live systems within 30 days and private backups age out within 90.

## 20. Added after the Phase 6.2 review (2026-10-25)

### A50 — Password reset by a 6-digit code · ADOPT (replaces A15's link plan for v1)
Khay Studios has no domain, so v1 has no email links and no app links: the reset uses a 6-digit code typed into the app. Email goes through Brevo's SMTP relay.

- `POST /auth/forgot-password {email}` → 202 with the same body for every email: known, unknown, deleted, and an account inside its 60-second resend cooldown. Every path computes the code hash once. For a live account, a new code (`random_int`, six digits, leading zeros kept) replaces any earlier unused one. It is stored only as an HMAC-SHA256 with the app key, looked up only among that account's rows, expires after 15 minutes, allows 5 wrong tries, and no new code is issued within 60 seconds of the last. Throttle: the existing `password-reset` limits, per IP and per email (429 past them). After 10 wrong tries for an account in a rolling 24 hours (`password_reset_failures`, one row per wrong try), no new code is issued for it, with the same 202, until the first of those tries is 24 hours old (6.4 review L1).
- The email is sent after the response (Laravel's `defer()`, which runs once per request; a terminating callback such as `dispatchAfterResponse` repeats in a long-lived process), so the free host needs no queue worker. A send failure logs only the exception class. Plain text and simple HTML: the code in large type, "It expires in 15 minutes.", and "If you did not ask for this, you can ignore this email; your password has not changed." No link of any kind. Sender name and address come from `MAIL_FROM_NAME` and `MAIL_FROM_ADDRESS`.
- `POST /auth/reset-password {email, reset_token, password, password_confirmation}` → 204. `reset_token` (the spec's field name) carries the six digits. Password rules as at registration: at least 12 characters, `confirmed`, and `Password::uncompromised()` (A16). A wrong, expired, used or exhausted code, or an unknown or deleted email, all get the same 422 `validation_failed` on `reset_token`: "This code is not valid. Request a new one." Each wrong try counts, and the fifth makes the code unusable.
- On success, in one transaction under the user lock: the new password hash, the code consumed, and every Sanctum token of the user deleted (every device signs out: "revoke old sessions"). No sign-in token is returned; the app goes to sign in.
- `password_reset_codes`: id (UUIDv7), user_id (FK), code_hash, expires_at, attempts, consumed_at, created_at; CHECK attempts between 0 and 5; a partial unique index allows one unconsumed row per user. It joins `AccountPurger::ORDER`. There is no `password_reset_tokens` table in this schema; Laravel's broker is not used.
- Mail config comes from the environment only: `MAIL_MAILER=smtp`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME`. Brevo's relay is `smtp-relay.brevo.com` on port 587. Local development uses the log mailer and tests use `Mail::fake`. No credentials are in the repository.
- The app: sign in (02) offers "Forgot password?", then 25 (request), 26 (check your inbox, resend after a 60-second countdown) and 27 (the code, then the new password twice). On 204 it opens sign in with the email filled and "Your password has changed. Sign in with the new one." Other sessions end through their 401 as an expired session does. Wherever the design says "link", the app says "code".
- Brevo processes the email address and the code email; privacy.md and facts.json name it.

## 21. Added after the Phase 6.4 review (2026-10-25)

### A51 — Deleting a habit, and swipe to archive or delete · ADOPT (Khay Studios' decision, 2026-10-25; replaces A34's "There is no habit delete in v1")
No design exists. Khay Studios approved building it from the app's existing components.

- New operation `habit.delete {base_version}` on entity `habit`, applied by the one MutationApplier and journaled under the user lock (A1). A stale `base_version` is 409 `version_conflict` with the current habit, as for `habit.archive`. The app re-sends a stale delete once on the server's version with a new mutation id, as A45 does for desired states (a delete's intent cannot be misread); a second conflict needs attention and can only be discarded (6.6 review L1). Allowed from active or archived. Already deleted: acknowledged with no change.
- The `habits` row stays as a tombstone: `deleted_at` set, `name` cleared to `''`, `unit` cleared, `version` + 1. In the same transaction the habit's owned content is removed: its logs (with notes), definition versions, active ranges, streak cache and period evaluations; its reminders become tombstones (as `reminder.delete` leaves them), so a later edit or delete of one answers `resource_deleted` naming the habit (6.6 review I1). Bootstrap leaves those tombstones out. Kept: `xp_entitlements` and `xp_ledger` (XP stays; ledgers are append-only and balances stay reconstructable, invariant 7), `freeze_usage` and `freeze_ledger` (the balance history), and `reward_state` unchanged. The level never drops because of a delete.
- Journal: one `delete` change for the habit (the tombstone entity, which now carries `deleted_at`; definitions and ranges empty), plus a `delete` change for each removed log and reminder (its last state with `deleted_at` set, version + 1), so other devices drop them. All take their seq under the lock.
- Every reader skips deleted habits: bootstrap, heatmap (404), insights (its XP still counts in the totals, as A47 says for archived habits; with no definitions it joins no category), exports (the habit and its logs are absent; XP rows keep the `habit_id`), period closing and its staleness check. Screen 16's ledger rows for it read "A habit" (the existing fallback).
- Writes to a deleted habit are rejected 409 `resource_deleted` with no change: `habit.update`, `habit.archive` and `habit.restore` name the habit (`resource_id`, `current` = the tombstone). Every `log.*` write and `reminder.create` on it carry `entity: "habit"`, `habit_id` and `current_version`. They have no `resource_id`, so the ack keeps the mutation's own entity id.
- Account purge (A49) removes the tombstone with everything else.
- Migration: `habits.deleted_at timestamptz null`, an index on (user_id, deleted_at), and a CHECK that a deleted habit has an empty name.
- The app:
  - `LocalMutationService.deleteHabit` writes the `habit.delete` outbox row with the confirmed version as `base_version`. In the same drift transaction it removes the habit's unsent log and archive/restore rows from the outbox, since they can never apply. **This is the one place invariant 8 ("never delete an unacknowledged outbox row") is relaxed**, and only for rows the person's own delete makes meaningless. It also removes the habit, its logs, drafts and reminders locally and cancels its notifications.
  - A pulled habit tombstone does the same on other devices, except for the outbox. An unsent row there comes back `resource_deleted` (entity habit) and the queue shows "This habit was deleted on another device." with Discard only.
- Gestures (Habits list 07 and Archived routines 22; never Today):
  - A swipe right past about 70 % of the row archives at once (on 22: restores), with an Undo (in the toast since A52).
  - A swipe left past it opens the "Delete {name}?" confirmation and the row springs back. Only "Delete habit" there deletes.
  - A shorter swipe shows the action and springs back. A light haptic marks the threshold.
  - Habit detail (12) has "Delete habit" too, and every swipeable row has screen-reader actions for Archive (or Restore) and Delete.

## 22. Added after the Phase 6.6 review (2026-10-25)

### A52 — Messages as the app's own toast, and icons from Hugeicons through one registry · ADOPT (Khay Studios, 2026-10-25)
The architect's 6.7 prompt asked for messages inside each screen with no toasts or overlays. Khay Studios decided otherwise when asked (2026-10-25): **a modern floating toast**. Snackbars "look outdated", and a message must never open a new page. This decision replaces the prompt's inline-message parts.

- **Messages:**
  - No Material `SnackBar` or `ScaffoldMessenger` anywhere, and no toast package. One in-app toast (`AppToast`): a rounded pill near the top of the screen, under the status bar, over the app's root overlay, so it survives the navigation after a save.
  - Contents: a tone icon, one line of text, and at most one action (for example Undo) with a 44 px target. The tone is shown by its icon as well as its colour (A12).
  - Timing: about 4 seconds without an action, 6 with one, then it fades. It can be dismissed with its close button or a swipe up. While a screen reader is on it stays until it is dismissed or replaced. A new toast replaces the current one.
  - Accessibility: announced as a polite live region; under reduced motion it appears and goes without sliding.
  - An architecture test fails if `app/lib` mentions `SnackBar`, `ScaffoldMessenger`, `showSnackBar` or a toast package.
  - The sign-in notices (A49, A50) stay as cards on that screen: they explain why the person is signed out.
- **Icons:**
  - Every icon in the app's own UI comes from the free Hugeicons stroke-rounded set (the `hugeicons` package on pub.dev), never the Pro package.
  - One registry, `lib/widgets/app_icons.dart`: `AppIcons.<meaning>` constants and one `AppIcon` widget that takes a size, a colour and either a semantic label or no semantics. This is the same pattern as Khay Studios' schoolbook app.
  - An architecture test fails on `Icons.` or a direct `HugeIcon` use outside that file. Material's own internal glyphs (a switch thumb, a date picker) and the Android notification drawable are out of scope.

## 23. Added after the Phase 6.7 review (2026-10-25)

### A53 — A chosen icon for each habit, from the whole Hugeicons set · ADOPT (Khay Studios, 2026-10-25)
A habit's icon shows what the habit is (a book for reading, a drop for water), chosen by the person. Its type no longer picks it. The architect's 6.8 prompt proposed a fixed catalog of about 40 keys. When it was run, Khay Studios decided the choice "shouldn't be limited": the picker offers **every free Hugeicons stroke-rounded icon (6,063 in hugeicons 1.2.0) with a search**. This replaces the prompt's fixed-catalog parts. No design exists for the picker. It is built from existing components (the Schedule and Reminder rows on 24, a bottom sheet), and Khay Studios approved that.

- **The key:**
  - `habits.icon` is `varchar(64)`, null by default.
  - A non-null key is the icon's Hugeicons name in lower-case kebab form, for example `book-02` or `water-energy`.
  - The server checks only the key's shape: `^[a-z0-9]+(-[a-z0-9]+)*$`, at most 64 characters. It does not check a list. So a newer app with a newer icon set can sync to an older server, and an older app keeps syncing (A21). Anything else is 422 `validation_failed` on `icon`.
- **Writes:**
  - `habit.create` accepts `icon` (optional, a key or null).
  - In `habit.update`, an `icon` that is absent leaves the icon unchanged, so apps from before this amendment never clear it. `null` clears it; a key sets it.
  - Changing only the icon raises the habit's `version`. It is presentation only: never a definition version, and it never changes periods, XP, streaks or freezes.
  - The key travels in the habit entity, bootstrap and exports.
- **Showing it:**
  - A null icon, or a key the app does not know, shows the category's default. An unknown key is kept unchanged on the next edit unless the person picks another (invariant 13).
  - The type's icon stays only where the type itself is shown (the type switch on 24).
- **The contract fixture** `contract-fixtures/habit/icons.json` holds:
  - the key shape;
  - each category's default key;
  - the keyword table (word prefixes of the habit's name, to a key);
  - the about 40 featured keys the picker shows first under "Suggested", each with an English label;
  - name-to-icon examples that both suites check.
  The server's copy of the table and the app's generated catalog are tested against it, never copied by hand.
- **Suggestion and backfill:**
  - On create, the name suggests an icon from the keyword table until the person picks one; after that, the name no longer changes it.
  - A one-time migration gives existing habits the same table's icon and leaves the rest null. It never overwrites a chosen icon.
- **Search:**
  - Each icon's searchable words are the words of its name, plus the keyword table's words and the featured labels pointing to it.
  - Search runs on the device, offline.
  - English only for now: icon names are not translated.
- **App size:** the whole set is bundled (no network fetch) so the picker works offline. The increase in app size is measured and reported in the 6.8 packet.
- **No new third party:** the icon set is the same MIT-licensed package A52 adopted, and an icon choice is not personal data beyond the habit itself.

## 24. Added after the Phase 6.8 review (2026-10-26)

### A54 — Production v1 on free tiers · ADOPT (Khay Studios, 2026-10-25 and 26)
No money and no domain. Claude Code prepares the repository and `docs/DEPLOY.md`. Khay Studios does every dashboard step and holds every secret. No secret, key, token, connection string or keystore is ever in the repository, a commit message, a log line or a review packet.

- **What runs where:**
  - **API:** one Render free web service in Frankfurt, a Docker image of `api/` (PHP 8.4, nginx with php-fpm in the same container, non-root). It is reachable only through Render's proxy, at `https://<service>.onrender.com`.
  - **Startup:** the start script caches config, routes and views, runs `migrate --force` (the free tier has no pre-deploy step), then starts the web server. There is exactly one instance; never scale it out.
  - **Database:** Neon free PostgreSQL in Frankfurt (AWS eu-central-1), through `DB_URL` with Neon's **direct** (not pooled) connection string and `sslmode=require`. Direct, because:
    - one instance needs no pooler;
    - writes rely on row locks (`SELECT … FOR UPDATE`, A1), `SET TRANSACTION` and advisory behaviour that PgBouncer's transaction mode can break between statements.
  - **Cache and queue:** the `database` driver on Neon, using the existing tables. The cache store carries the scheduler's `withoutOverlapping` locks and the rate limiters.
  - **Files:** photos (A20) and exports (A48) go to the Cloudflare R2 bucket `habit-files` (Western Europe, public access disabled), through an `r2` disk on the S3 driver (path-style, region `auto`). The API keeps streaming each object to its owner. It never makes a public or presigned R2 URL.
  - **Email:** Brevo's SMTP relay (`smtp-relay.brevo.com`, port 587, STARTTLS) from a verified sender address.
  - **The app:** a signed release APK on a GitHub Release, with a download page on GitHub Pages beside the legal pages.
- **The tick** (the free tier has no cron and no worker): `POST /api/v1/internal/tick`.
  - **Secret:** the request carries `X-Tick-Secret`, compared with `TICK_SECRET` by `hash_equals`. A missing header, a wrong secret, or no `TICK_SECRET` configured all answer **404** `not_found`, never 401, so the endpoint is not advertised. It sits outside Sanctum and is throttled per IP.
  - **Work:** `schedule:run`, then `queue:work --stop-when-empty` with `--max-time=50` and a memory limit; answers 204.
  - **No double runs:** one tick at a time holds a cache lock. A tick that finds the lock taken answers 204 and does nothing. The scheduled commands keep `withoutOverlapping`, and the queue's own reservation keeps a job from running twice.
  - **Caller:** cron-job.org every 5 minutes. That also keeps the free service from sleeping.
- **Health** (`GET /api/v1/health`): outside `local` and `testing` it answers **503** `unavailable` when any of these holds:
  - the export signing key is a test or short key (6.1 review L3);
  - `SELECT 1` on the database fails within about 2 seconds;
  - `MAIL_MAILER` is `log` or `array`;
  - `MAIL_FROM_ADDRESS` is empty or ends in `example.com` (the 6.4 review's answer).

  The body says only `ok` or `unavailable`; the reason goes to the log. Render's health check uses this path, so a bad configuration never takes traffic.
- **Minimum app version** (the 6.6 review's I2):
  - `MIN_APP_VERSION` (an integer build number, default 1) travels in every success envelope's `meta.min_app_version`, `/health` included.
  - An app whose own build number is lower shows a calm full-screen "Please update" view. Its only way forward is a button to the download page (`DOWNLOAD_PAGE_URL`, a dart-define).
  - The first release's build number is the first value.
- **Proxies and HTTPS:** Render's proxy is trusted (`TRUSTED_PROXIES`, default `*`; the service has no other entrance), so `request()->ip()` is the client's address and the per-IP throttles work. URLs use `APP_URL` (https). Responses carry `Strict-Transport-Security` outside local and testing.
- **Logs:** `LOG_CHANNEL=stderr`, level `warning`, `APP_DEBUG=false`. No request body, token, code, password or email is ever logged (invariant 11; a test reads every log call).
- **Limits Khay Studios accepted:**
  - Render's free service sleeps after about 15 idle minutes, and a missed tick means a cold start of up to a minute. It has 750 free hours a month, so only one free service should run in the workspace.
  - Queued work (exports, the account purge, period closing) waits for the next tick: up to about 5 minutes.
  - Neon free has 0.5 GB of storage, and its compute suspends when idle; the first query wakes it.
  - R2 free has 10 GB.
  - Brevo free sends 300 emails a day, and reset emails can land in spam.
  - The APK is installed by hand: allow "install unknown apps".
  - These limits are reviewed before inviting more than a few testers.
