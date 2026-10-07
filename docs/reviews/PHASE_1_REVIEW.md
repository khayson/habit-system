# Phase 0.1 + Phase 1 review — architect

Reviewed for Khay Studios · 2026-10-07

**Basis: the packet only.** The repository was private when I tried to clone it, so this review covers the packet (signatures, fixture results, assumptions, risks), not the code. A code-level pass follows once I can read the repo (see the spot-check list at the end). Verdicts below are provisional on that.

## Verdict

- **Phase 0.1: accepted.** Every follow-up is addressed, CI is green on `56c9fd9` per the packet, and the deviations (`platform.php` 8.4.1, limiter test moved to Phase 2) are sound.
- **Phase 1: accepted provisionally.** The approach is right: pure classes with an injected clock, fixtures written first with explicit seeds, property tests with fixed seeds, a mutation check (four injected bugs, all caught), and gates that fail when a suite ignores a fixture. Phase 1.1 below must land before Phase 2, because Phase 2's `MutationApplier` will be written against the `HabitType` interface.

## Answers to open questions

**Q1 — Operation names.** The wire names are the A21 generic ones: `log.set_value`, `log.increment`, `log.set_item`, `log.set_note`. The spec's names stay accepted as aliases for the built-in types only: `log.set_binary` → `log.set_value` (value 0 or 1, binary habits only); `log.increment_quantity` → `log.increment` (quantity only); `log.increment_duration` → `log.increment` (duration only, delta in seconds). Normalise aliases in one place (the `MutationApplier`'s operation normaliser) before validation. Using an alias on the wrong type returns 422 `unsupported_operation`. Receipts store the canonical name. `HabitType::operations()` lists canonical names only. The app sends canonical names only; remove the aliases before the first public release if nothing uses them. Record as **A27**.

**Q2 — Zone changes.** Acceptable, and it is the better behaviour. State the invariant: *an event's date never goes backwards*. A day that began under the old zone ends at the next local midnight in the zone then in force (a long day travelling west, a short one east). Record as **A26**, with two conditions:
- the year-walk property test must include zone-change entries, not only DST (please confirm it does);
- `profile.set_timezone` creates its calendar entry effective at the user's next local midnight in the *old* zone, never at an arbitrary instant. That keeps the transitional day to one well-defined case.

**Q3 — Partial weeks (`A1-week-partial`).** Confirmed. Record as **A28** together with the other Phase 1 assumptions, which are all accepted: 25-hour habit-day cap, insights window owns periods whose start date falls inside it, opt-in decided at the period's `ends_at`, zero-delta `cap_reached` row for a grant at the cap, increments > 0, half-up rounding (integer arithmetic only, no floats). Add test cases: start on Saturday with count 3 → not due; start on Thursday with count 4 → due (Thu–Sun); pause mid-week; restore mid-week.

The one assumption I am changing is `no_calendar`; see R1.

## Phase 1.1 — before Phase 2

- **R1 — First calendar entry governs earlier instants.** An event before the first entry uses the first entry (still bounded by the 90-day age rule) instead of failing with `no_calendar`. Otherwise a new account on a phone whose clock runs a few minutes slow would have its first check-in rejected, and restoring older history would fail. Keep `no_calendar` only for an empty timeline.
- **R2 — Make `HabitType` ready for Phase 4b.** The registry exists to avoid a later signature change, but from the signatures `apply(string, int, mixed): int` and `isComplete(int, int)` are scalar-only and `DefinitionVersion` has no `config`, so a checklist (item states in `detail`, item ids in `config`) cannot be expressed. Add `config` (array, default `[]`) to `DefinitionVersion` (A21). Introduce `LogState { int $value; array $detail }`. Change to `apply(string $operation, LogState $current, mixed $operand, DefinitionVersion $definition): LogState` and `isComplete(LogState, DefinitionVersion): bool`. The built-in types ignore `detail` and `config`. Add a test-only `FakeChecklistType` that implements `log.set_item` and "all items done" to prove the interface needs no engine changes.
- **R3 — Domain errors become API errors in one place.** Add to `docs/api-error-codes.md`, with fixtures: `future_event`, `event_too_old`, `timezone_context_mismatch`, `backdate_future`, `backdate_too_old` (from `DayResolutionException`), and `unsupported_type`, `unsupported_operation`, `invalid_value` (from the habit exceptions). One mapper, tested against the fixtures.
- **R4 — Guard the boundaries.** Add a scan test: only `TimezoneTimeline` and `PeriodEngine::bounds()` may compute period or day start/end instants. This turns the packet's own risk #1 into a failing test.
- **R5 — Randomised seeds nightly.** Keep the fixed seeds in the normal run; add a nightly CI job with random seeds that prints the seed on failure. Extend the mutation check to at least eight mutants (add: week starting Sunday, off-by-one at the 90-day edge, DST repeated hour, `weekly_count` counting check-ins instead of days).

## Carry to Phase 4

The server must enforce "next eligible period" when it creates a definition version (the packet's risk #2). Add `HabitSchedule::nextEffectiveDate(LocalDate $today)` to the domain, tested: daily and weekdays → tomorrow; weekly → next Monday; interval → the start of the next period under the current definition. The versioning service uses it and never accepts a client-chosen effective date.

## Phase 2 is split

**Phase 2a — backend only**, then a review checkpoint with me before 2b.
- Migrations 1–4 (A18), Sanctum with UUID users, auth endpoints, `MutationApplier` (`habit.create`, `log.set_value`), receipts, journal (A1), `/sync`, `/sync/bootstrap`, error mapping.
- Gate: duplicate retry → one log; interrupted pull replays safely; delete vs queued mutation → `resource_deleted`; three days offline → three original dates; **A1 concurrency test on real PostgreSQL**; cross-owner 404 on every route and sync entity; the two-users-behind-one-IP limiter test (carried over from Phase 0).

**Phase 2b — app**: drift tables, `LocalMutationService`, sync engine, screens 02, 03, 04, 05 (binary only) and 18, and the two-emulator convergence demo.

**Watch-outs for 2a**
- Sanctum's default migration uses a `bigint` `tokenable_id`. With UUID users, switch it to `uuidMorphs('tokenable')` and test token auth for a UUID user. Tie each token to a device so logout revokes both (A6).
- Transaction shape for every mutation: begin → `SELECT … FOR UPDATE` on the user row → look up the receipt (same `mutation_id` and hash → return the stored result; different hash → 409) → apply → insert receipt and journal rows with `seq = ++users.change_seq` → commit. The receipt insert must be inside the locked transaction.
- `/sync` returns HTTP 200 with per-mutation acks. Conflicts embed the Phase 0 error object under `ack.error`, same shapes, `entity` included.
- Pull: `seq > cursor ORDER BY seq LIMIT n+1`, `has_more` from the extra row, cursor opaque and bound to the user.
- `occurred_at` accepts fractional seconds and is stored at full precision; only server-generated times are emitted as whole seconds.

## Carry to Phase 7

Make sure production PHP's timezone database is current and log `timezone_version_get()` at boot. Persisted `starts_at`, `ends_at` and `resolved_timezone` already protect stored history from later tzdata changes.

## Spot-check list for the code-level pass

What I will read once I have access:
- `TimezoneTimeline` and `DayResolver`: the transition-table algorithm (repeated hour, skipped midnight, A22 offsets, zone-change entries) and the tzdata assumptions.
- `PeriodEngine::periods` and `evaluate`: partial-week rule, definition governing a week, `bounds()`.
- `FreezeEvaluator::closePeriods`: A8 ordering, `usedKeys` including refunded usages, cap handling.
- `QuantityType::parseValue`: rejects JSON floats, exponents, more than three decimals and negatives; integer arithmetic only.
- `ConsistencyCalculator::percent`: integer rounding.
- The arch and scan guards and the fixture loaders in both suites.