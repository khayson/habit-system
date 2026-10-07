# Phase 0 review — architect

Reviewed for Khay Studios · 2026-10-07 · reviewer: Claude (architect role)

## Verdict: ACCEPTED, with Phase 0.1 follow-ups

I did not rely on the packet alone. I cloned the repo and read the code. Verified:

- CI run #1 on `895b0c1`: **Success** (api 44 s, app 3 m 23 s). Annotations match the packet (Node 20 deprecation; `ubuntu-latest` → Ubuntu 26 on 19 Oct 2026).
- `CLAUDE.md` and the three plan docs in the repo are identical to the issued versions (line endings aside).
- Envelope, exception renderer, request id, rate limiters, `UtcTime`: match the spec. The renderer uses fixed messages and cannot leak exception text; `/health` returns only `status` + `server_time`. Fixtures for 409 `version_conflict`, 409 `resource_deleted` and 429 match the spec shapes.
- `private` disk has `serve => false`, no public disk (A20). PostgreSQL session is UTC.
- Cleartext HTTP is **debug-only** (`src/debug` manifest, network-security config limited to `10.0.2.2` / `localhost` / `127.0.0.1`). Release keeps Android's HTTPS-only default.
- Dark and light token values map exactly as A13e prescribes. `infoInk` is `#256E82` (A13d).
- No secrets, no `.env`, no personal paths in the tree or history. `DEV_SETUP.md` uses `<you>` placeholders.

## Needs Khay Studios now (not Claude Code)

**F1 — The repository is public.** The packet says private, but an unauthenticated clone works and GitHub shows "Public". It contains both spec PDFs (about 37 MB, the product's design and contract). Nothing secret was found, so nothing needs rotating. If this is not deliberate: Settings → General → Danger zone → Change visibility → Private. Check your plan's included Actions minutes for private repos (CI is about 4 minutes per run).

**F10 — Two Figma updates.** (a) Change the `infoInk` variable to `#256E82` so design and code do not drift. (b) Compare one dark screen (for example the "Same rules. Different theme" card) with the app's dark theme, since the dark values were exported unlabeled and mapped by order.

## Answers to open questions

1. **Error codes — approved**, all of: `unauthenticated`, `forbidden`, `not_found`, `method_not_allowed`, `payload_too_large`, `rate_limited`, `server_error`, `bad_request`, `unsupported_media_type`, `unavailable`, `http_error`, plus the spec's `validation_failed`, `version_conflict`, `idempotency_mismatch`, `resource_deleted`, `cursor_expired`. Reserve for later phases: `timezone_context_mismatch`, `dependency_pending`, `unsupported_operation` and `unsupported_type` (A21). Codes are contract: see F9.
2. **`resource_deleted` shape — approved** (`resource_id`, `current_version`). Add `entity` (the entity type name). In `/sync`, per-mutation conflicts come back inside the ack, not as HTTP 409; the ack's `error` object must reuse exactly these shapes (Phase 2).
3. **Rate-limit numbers — approved as defaults.** Keying is right: user id when authenticated, IP otherwise (important for mobile carriers that share IPs). Phase 2 must prove it with a test: two users behind one IP get independent `api` and `sync` buckets, and the throttle runs after authentication (otherwise it silently falls back to IP). Make the numbers env-configurable. Revisit the `auth` per-IP 20/min with real traffic.
4. **Flutter — stay on 3.47.x.** The spec's 3.44.x was a target to confirm. Pin it in `pubspec.yaml` (`environment: flutter:` range) as well as CI, and update `CLAUDE.md`.
5. **Font — bundle Inter** (variable font, OFL license file), after Khay Studios confirms the typeface in Figma text styles. Keep a platform-font fallback. No runtime font downloads (offline-first).

## Deviations

All accepted. 1 (PHP 8.4 in user space), 2 (no Docker locally), 6 (whole-second wire timestamps), 7 (placeholder routes), 8 (skeleton removals, `CLAUDE.md` casing verified) and 9 (pins) need no action beyond the follow-ups below. 3, 4 and 5 are covered by answers 4, F9 and F10.

## Phase 0.1 follow-ups for Claude Code

Do these first, as small separate commits, before Phase 1.

- **F2 — CI hardening.** `runs-on: ubuntu-24.04` (before 19 Oct); `permissions: contents: read`; `timeout-minutes` on both jobs; move `actions/checkout` and `actions/cache` to current Node-24 majors (verify the versions); add `composer validate --strict`, `composer audit` (fail on high/critical) and `docker compose config -q`; add Dependabot for composer, pub and github-actions.
- **F3 — composer.** Set `config.platform.php` to `8.4.0` so resolution cannot drift to the dev machine's PHP 8.5. Remove the `npm install` / `npm run build` lines from the `setup` script (API-only).
- **F4 — Release guard.** `ApiConfig` must throw at startup if `kReleaseMode` and the base URL is not `https://`. Test it.
- **F5 — 401 handling in `ApiClient`.** Act only when the failed request carried a token, and clear the stored token only if it still equals the one that request used. Otherwise a late 401 from an old session clears the new session's token after a logout/login. Test both cases.
- **F6 — Durability.** Change `PRAGMA synchronous` from `NORMAL` to `FULL`. In WAL mode `NORMAL` can lose the most recent commits on an OS crash or power loss, which contradicts "saved on this device" (invariant 8). Write volume is tiny, so the cost is negligible. Update ADR 0001 and the spike test.
- **F7 — Stronger guards.**
  - Domain purity: the current arch test only catches `now()`, `today()`, `time()` and `date()`. Add a scan of `app/Domain` for `new DateTime(Immutable)?()` with no arguments and `Carbon(Immutable)::(now|today|yesterday|tomorrow|parse)`.
  - Mass assignment: forbid `unguard()` and `$guarded = []` anywhere in `app/`.
  - Dart: fail the test suite if `NativeDatabase` or `driftDatabase(` appears outside `lib/data/database_opener.dart` (ADR 0001 says it is the only opener).
- **F8 — Inter** bundled with its license (after the Figma check).
- **F9 — Docs.** Update `CLAUDE.md` and `docs/SPEC_AMENDMENTS.md` for Flutter 3.47.x and for error `meta` carrying `server_time`. Add `docs/api-error-codes.md` listing every code, status and shape, with one golden fixture per code in `contract-fixtures/envelope/`. In `DEV_SETUP.md`, mark `docker-compose.yml` as not yet run locally and say when the analyzer pin can be removed.
- **F11 — Non-text contrast.** Add a 3:1 check for `progress` and `focus` against their surfaces. `progress` on white is about 2.8:1: record it as a documented exception, valid only because a number or text always accompanies it.

## Carry into later phases

- **Phase 2**: publish the Sanctum config with `expiration` = 120 days and token abilities (A6). Hash `Idempotency-Key` payloads over the client's original payload (accept fractional seconds in `occurred_at`; only server-generated times are emitted as whole seconds). The A1 concurrency gate runs on real PostgreSQL. The app's 401 handler never touches the outbox.
- **Phase 7**: trusted proxies (so `$request->ip()` is the client, not the load balancer), `DB_SSLMODE=require` or stricter, `APP_DEBUG=false`, HTTPS/HSTS, rate-limit store moved off the database cache if load demands it, decision on SQLCipher.

## Phase 1 decision pre-made

Fixture seed for the weekly insights example (A12): use only the five daily/weekday habits (Water, Meditation, Reading, Morning plan, Less sugar); Running and Pilates are excluded from that fixture and declared so in its seed. Revisit if Khay Studios wants Running included.