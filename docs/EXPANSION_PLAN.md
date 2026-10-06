# Expansion plan — habit types and retention

Prepared for Khay Studios · 2026-10-06

All 36 designs are in scope. This plan covers what we add **beyond** them, and how to add it without destabilising the core. Sizes: S ≈ days · M ≈ 1–2 weeks · L ≈ 2–4 weeks.

---

## 1. Product guardrails

The goal is an app people keep using. The accepted design and spec already say how we earn that. These guardrails come from the design's principles page and spec contract 09. Changing one is a deliberate product decision recorded in `SPEC_AMENDMENTS.md`, never something a feature does quietly.

- A missed day is a pause, not a failure. No shame, no loss-threat copy.
- Private by default: no public streaks, profiles, leaderboards or guild damage.
- Rewards are deterministic and explained: no random-reward promises, no paid economy.
- Notifications are opt-in and useful, and never the only way to do something.

**Design bet — what produces staying power in a habit app**
1. Near-zero friction to log (widgets, notification actions, auto-logging).
2. The app becomes more valuable the longer it is used (history, insights, correlations).
3. Rituals (weekly review, milestones, challenges).
4. Gentle recovery after a lapse.

Compulsion mechanics (streak shaming, loss-threat pushes, random rewards) work against this: a broken streak under pressure is the most common moment a user deletes the app. The freeze-token design exists for that reason.

---

## 2. Habit type framework

The spec's three types bundle several decisions into one word. Split them, and new types become configuration plus a registry entry, not a rewrite.

| Dimension | Meaning | Values |
|---|---|---|
| Value kind | what is stored in `value` / `detail` | boolean · decimal (unit) · duration (s) · scale (min..max) · time-of-day · checklist · text |
| Log semantic | how a log changes | set · increment · set_item |
| Success rule | when a day/period counts | completed · threshold (≥) · limit (≤) · time window · all items · any value · none (track-only) |
| Evaluated | when success is decided | immediately · at period close |
| XP | reward | on completion · at close · none |
| Streak | participates? | yes · no |
| Aggregation | insights roll-up | sum · count · last · avg · max |

**Existing types in this model**

| Type | Value kind | Semantic | Rule | Evaluated | Aggregation |
|---|---|---|---|---|---|
| binary | boolean | set | completed | immediately | count |
| quantity | decimal (unit) | increment / set | threshold ≥ target | immediately | sum |
| duration | duration (s) | increment / set | threshold ≥ target | immediately | sum |

**Registry (A21).** Each type implements one strategy on the api and one widget set on the app:
- value schema + validation; allowed operations;
- completion predicate and evaluation timing;
- XP eligibility; streak participation; insights aggregation;
- UI: Today card (4 states), entry control, create/edit fields, detail view, a11y labels.

**Data shape.** `habits.type` is `varchar(24)` checked by the registry. Definition versions carry `config jsonb` (type-specific, with stable item ids so renaming or removing an item never rewrites history). Logs carry `value` (the scalar the rule evaluates), `detail jsonb` and a universal encrypted `note`.

**Wire protocol.** Keep it generic: `log.set_value`, `log.increment`, `log.set_item`, `log.set_note`. Increments commute; absolute edits conflict (spec rule). Checklist items are per-item absolute states: edits to different items merge; the same item changed on two devices resolves in server receipt order (not clocks) with a non-blocking notice — see D3.

**Forward compatibility (A21).** Mobile updates lag the API. The app must preserve and display-as-placeholder any type it does not know. The server rejects unsupported operations (422) and creation of undeclared types. Additive changes do not bump `/v1`.

---

## 3. Candidate types

| # | Type | Value kind | Success rule | Evaluated | Size | Notes |
|---|---|---|---|---|---|---|
| 1 | **Checklist routine** (morning/evening steps) | per-item booleans | all items (or ≥ N) | immediately | M | Items versioned; partial progress "3/5 steps". |
| 2 | **Limit / stay under** (coffee, sugar, screen time; "avoid" = target 0) | decimal + unit | value ≤ target | at day close | M–L | Pending until close; exceeding marks Missed at once; XP at close. Fits the five existing statuses. Copy must stay gentle. |
| 3 | **Rating** (mood, energy, pain) | scale | any value logged | immediately | S–M | "Log it" habit; feeds correlation insights. |
| 4 | **Measurement** (weight, blood pressure) | decimal + unit, set | none (track-only) | n/a | S–M | Trend chart; no streak; consistency excludes it. Sensitive. |
| 5 | **Time-of-day** (wake by 6:30, bed by 22:30) | time-of-day | ≤ / ≥ target time | immediately | M | After-midnight values rely on the day-start offset (A22). |
| 6 | **Period total goal** (run 30 km/week, read 300 pages/month) | decimal + unit | sum over period ≥ target | at period close | M–L | New schedule kind `period_sum`; period-level progress UI. |
| 7 | **Challenge** (30-day, fixed end date) | any type + end date | underlying rule + finishing the range | — | S–M | Uses active-range end; completion moment. |
| 8 | **Multi-slot** (3 doses per day, with times) | per-slot booleans | all slots | immediately / at close | M | Per-slot reminders. Medication use needs "not medical advice" wording. |
| 9 | **Journal** (one line a day) | text | non-empty | immediately | S–M | Encrypted at rest. |
| 10 | **Health-platform-backed** (steps, workouts, mindful minutes) | decimal / duration from OS | threshold | automatic | L | Health Connect on Android first; dedupe vs manual logs; permissions; iOS needs a Mac route. |

**Not a type — universal:** optional note (and later mood tag) on any log. Build with Tier 1; it makes every habit's history richer.

**Recommended tiers**
- **Tier 1 (Phase 4b)**: 1 checklist, 2 limit, 3 rating, 4 measurement, plus notes. They share the new infrastructure (`config`, `detail`, registry), so doing them together is cheaper than apart.
- **Tier 2 (Phase 9)**: 5, 6, 7, 8, 9.
- **Tier 3 (Phase 10)**: 10; photo-proof and geofence habits are deliberately out (storage/moderation and background-location cost outweigh value).

Notes, measurements and journals can be health-related: encrypt note text at rest, keep it out of logs, say so in the privacy policy.

---

## 4. Engineering impact checklist (per new type)

- **Schema**: only `config` / `detail` values; no new tables unless a type needs queryable rows (checklist items stay inside `config` / `detail`).
- **API / sync**: reuse the four generic operations; add `unsupported_operation` rules to the type's strategy.
- **Evaluators**: completion predicate, timing (immediate vs close), `period_evaluations` entries; freeze rules unchanged (a frozen period is never a completion).
- **XP**: eligibility and timing declared by the strategy (at-close types award at closure; reversal rules unchanged).
- **Insights**: aggregation declared by the strategy; track-only types excluded from consistency.
- **App**: Today card ×4 states (Pending / Queued / Conflict / Complete), entry control, create/edit fields, detail view, a11y labels, offline behaviour.
- **Tests**: fixtures first (rule, timing, XP, insights, DST/offset cases) + an old-app-version simulation.

## 5. Design drop checklist (per new type — needed before UI work)

Today card in four states · entry control (sheet or inline) · create / edit form fields · detail screen and heatmap meaning · empty and error copy (gentle) · accessibility labels · how the type appears in insights · dark theme.

---

## 6. Retention features (value-driven)

| Feature | Lever | Depends on | Size | Guardrail check |
|---|---|---|---|---|
| Quick-log from notification buttons and home-screen widgets | removes friction (biggest single lever) | Phase 3 outbox; drift writes from a background isolate | M–L | OK |
| Smart reminder suggestions ("you usually do this near 8:20") | right time, higher completion | on-device log history | S–M | OK — suggest, never auto-change |
| Weekly review ritual (recap + one-line reflection) | ritual + reflection | insights (14), notes | S–M | OK |
| Personal achievements (deterministic badges from the ledgers) | recognition of progress | XP ledger | M | OK — no randomness |
| Starter packs / templates | faster first habit | create flow | S | OK |
| Challenges | finite, celebratory goals | type 7 | S–M | OK |
| Correlation insights ("on days you meditate, mood tends to be higher") | data gains value over time | rating type, minimum sample size | M | OK — "tends to", never causation |
| Comeback flow (shrink-and-restart after a lapse) | recovery beats guilt | existing "Start again, gently" copy | S–M | OK |
| Habit stacking (after X → Y) | cue design | checklist or chained reminders | M | OK |
| Level curve tuning | pacing | A9 server-side level | S | OK |
| User-initiated share card (image of own recap) | pride, organic growth | recap | S–M | Decision D4 |
| Optional private 1:1 accountability partner | social commitment | new privacy model, invites, abuse handling | L | Changes contract 09 — D5 |
| Watch / Wear companion | friction | widgets | L | OK |
| Health auto-logging | friction | type 10 | L | Privacy review — D6 |

---

## 6b. Foundations to lay now (A23)

The features in section 6 are cheap if a few foundations exist before the core is built, and expensive to retrofit.
- **One local write path.** Every local change goes through a `LocalMutationService` (pure Dart, no UI dependencies). The app, notification action buttons, widgets and background sync all call it. It writes projection + outbox in one transaction.
- **A database that is safe outside the UI isolate.** Background sync, notification actions and widgets run outside the UI isolate. Phase 0 picks and proves one drift multi-isolate approach with a small spike, instead of discovering the problem in Phase 3.
- **Notification action payloads** use a fixed schema (`log:{habit_id}:{operation}:{value}` plus the reminder's local-date slot) so an action can run without opening the app and can be deduped.
- **Pause is already expressible.** `habit.pause {until_date}` ends the current active range today and inserts a future-starting one; no new table. "Shrink and restart" is a versioned target edit effective next period.
- **Weekly review needs one new entity**: `weekly_reviews (id, user_id, week_start DATE, reflection text encrypted, version)` as a sync entity with a `review.set_reflection` mutation (Phase 8).
- **Widgets** read a small app-written snapshot (today's habits, values, targets). Android first; iOS WidgetKit needs a Mac route.

---

## 7. Decisions (recommended default in brackets)

**Confirmed by Khay Studios, 2026-10-06:** retention approach = value, not compulsion (sections 1 and 6); D1 = all four Tier-1 types plus notes. D2–D7 = the bracketed defaults below, confirmed 2026-10-06 and revisitable when their phase starts (D5 still needs a spec amendment before anyone builds it).

- **D1** Which Tier-1 types ship first? **Confirmed: all four + notes**
- **D2** XP for track-only and log-it habits? [rating and journal earn the daily 10 XP (the log is the habit); measurement earns 0]
- **D3** Checklist same-item conflicts? [per-item absolute state, server receipt order, non-blocking notice]
- **D4** User-initiated share card? [yes, later; user-triggered image, no public profile]
- **D5** Private accountability partner? [not in v1; revisit after Phase 8; needs a spec amendment]
- **D6** Health auto-logging? [Android Health Connect first, after Phase 9, after a privacy review]
- **D7** Day-start offset UI? [after Phase 3; engine support from Phase 1]

## 8. Sequencing

Phase 1 builds the registry and day-start parameter (cheap now, costly later). Phases 2–4 ship binary / quantity / duration through the registry. Phase 3b adds profile photo and location. Phase 4b adds Tier 1 once designs exist. Phases 8–10 follow the core release. See `BUILD_PLAN.md`.