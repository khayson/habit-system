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