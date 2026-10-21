# Phase 5.3a review (GET /insights and the app's data layer)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-21
Scope: `06f07e6..0ec75cb` (9 commits, 21 files, +1,173 / −15). Read at code level: `InsightsQuery` and `InsightsController` in full, the route, the `TestCase` change; on the app, `models/insights.dart`, `insights_service.dart`, the `AccountContext`, `LocalMutationService`, `CompletionWait` and amount-screen diffs; the two new flow tests; the `SPEC_AMENDMENTS` (A47) and `BUILD_PLAN` diffs. Read in part: `InsightsEndpointTest.php` (the case loader and seeding helper), `insights_service_test.dart` (by test name), the fixture (by case name), and the five new mutants (by the packet). I checked the XP ledger and active-range schemas to answer the packet's questions. I did not run any suite.

## 1. Verdict

**Phase 5.3a is accepted.** The endpoint takes the window from the user's own calendar and never from the client, reuses the engine the closer stores from, takes closed periods' status from the stored rows, and gets every count and percentage from `ConsistencyCalculator`. The app reads the endpoint into immutable types it never stores or computes from. Both 5.2c findings are fixed with failing tests first. One Low finding changes `xp_earned` (it answers the packet's second question). Three Info notes. Nothing blocks 5.3b.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `0ec75cb2008afa6832432fd398aa69df8b60bc7e`. 9 commits; the first is `77c65d4`, and `PHASE_5_2C_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Run 39588421657 on `0ec75cb`: success, push, 3m39s: api 1m58s, docker-compose 6s, app 3m34s, e2e 1m23s. The page shows only the overall result and the job times |
| Test counts | From the packet: Pest 646 to 661 (+15, the endpoint tests), Flutter 754 to 772 (+18: two flow tests and the service, fixture and bar-scale tests). Mutation check 51 of 51, five new |
| 5.2c L1 | `completeBefore` is read at the start of the same transaction in both write paths; `mayEarnXp = completeAfter && (!completeBefore || coalesced)`; `CompletionWait` uses it. The new test syncs a complete day, adds 0.5 L and asserts Today, no "That counts." and zero transport calls |
| 5.2c L2 | `_frozenSaved` is set at the save and used in place of the live total while the screen is busy; a failed save clears it. The test holds the transport, saves and asserts "2 / 2 L" stays and "4 / 2 L" never shows |
| Endpoint shape | `period` required (`week` or `month`), `category` optional from `DefinitionVersion::CATEGORIES`, any other key refused; 422 `validation_failed` with the field named, the same as `/heatmap` and `/rewards`. Owner-scoped through `user_id`; the lazy closer runs first |
| Window | Today from `UserCalendar::timeline($userId)` at the frozen clock; week Monday to Sunday; month from the 1st to the day before the next month's 1st (February tested). `through` is yesterday, or null before the window's first closed day |
| Rules | Closed periods take completed, protected or missed from `period_evaluations`; open ones keep the engine's status; the calculator filters by start date (A28), counts protected in the denominator only, rounds half up and returns null for an empty window. `by_category` follows the category order and skips empty categories; a test asserts the sum |
| Week extras | `days`: seven entries; past and today carry counts of day periods, future days null; `open` only for today. `open_periods`: weekly habits whose current week is open, with completed distinct days and the target |
| App | `Insights.fromJson` requires the fields the screens need, keeps `percent` nullable and the category as a plain string; a decode failure becomes `unexpected_response` and nothing is kept. The service keeps the last answer per period and category in memory only. `InsightsDay.scale` and `barFraction` are display arithmetic with tests. No screen, route or tab change |
| Fixtures | One file, eight cases, both suites; the week and month cases build on `domain/insights.json` rather than copying it; the seed goes through the real `/sync` path |
| Legal | Nothing new is collected; "no change" holds |

## 3. Findings

**L1 · Low · `xp_earned` should be the XP the person was actually given**
The packet's second question. `earnedXp` counts completed days inside closed periods, so it leaves out two things A40 pays for: a check-in on a not-due day, and the days of a weekly habit whose week is still open. Screen 16 shows the ledger, and a "+90 XP" on 14 that is lower than what 16 lists for the same days would read as XP taken away. Fix: `xp_earned` = 10 × the active `xp_entitlements` rows (net of reversals, so it equals the ledger) whose `log_date` falls between the window's `start` and `through`, or 0 when `through` is null. Today stays out ("Through 27 May"). With a category filter, count only habit-days whose definition in force on that date has that category, the same rule A47 uses for periods. Archived habits keep their XP here: archiving never takes XP back. Update A47, the fixture (add a not-due check-in and an open weekly habit with a completed day to the week case, and expect them in `xp_earned`), the Pest and Dart tests, and change the mutant that covered `earnedXp`. `ConsistencyCalculator::earnedXp` then has no caller; remove it with its test, or keep it only if something else still uses it.

**I1 · Info · Archived habits are left out wholesale**
The spec's consistency row says "exclude archived dates"; A47 and the code leave out every habit that is archived now, including its periods before it was archived. My prompt asked for this, and it matches design 14's note ("archived routines are excluded"). Archiving a habit therefore changes this week's percentage at once, and restoring it brings the periods back (the archived gap stays out through its active ranges). Accepted as the product rule; no change.

**I2 · Info · A coalesced save can still wait on an already-complete day**
`mayEarnXp` is true for a coalesced write even when the day was already complete and confirmed (a pending further increment, then another one that joins it). The ack carries no XP, so the wait ends on the ack. The cost is one round trip in a rare case. No action.

**I3 · Info · Each request is one log query and one evaluation query per habit**
The packet's risk. It is fine at today's scale. Phase 7's load test should cover `/insights` next to `/sync`.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 `validation_failed` with the field, not `invalid_value` | Accepted, and my prompt was wrong: `invalid_value` is the habit-type value error. Consistent with `/heatmap` and `/rewards` |
| 2 Any other query parameter is refused | Accepted. It keeps a `date` from creeping in |
| 3 Periods from the engine, status from the stored rows | Accepted. The stored rows hold no day counts, and the heatmap already does the same |
| 4 A period's category is the definition's in force | Accepted; it is in A47 |
| 5 The key choices (`through` null, week-only keys, null future counts, `due` for day periods only) | Accepted; all in A47 |
| 6 `freezeClock` made public | Accepted; test support only |
| 7 No new ASSUMPTION tags | Noted |
| 8 `docs/legal`: no change | Accepted |

## 5. Open questions (answered)

1. **The day bars count only day habits. Intended?** Yes. A bar is completed against due on that day, and a weekly habit is not due on any single day; its progress has its own row ("2 of 3 distinct days this week"). Keep it, and keep the A47 sentence that says so.
2. **Is "+90 XP" meant to be the ledger?** Yes. See L1.

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 64 of `docs/DEVICE_GATE.md`.**
- **Insights read only what has synced.** Check-ins waiting in the outbox are not in the server's numbers, so 14 and 15 must say so when the outbox holds unsent log changes (5.3b).
- **A new week starts with nothing closed.** On a Monday `through` is null and the totals are empty; 5.3b must show that calmly, never as 0%.
- **A timezone change can move the freeze watermark backwards** (from 5.1). No test.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **My 4.1 review still carries one wrong sentence**; the 4.2a review has the correction.
- **Dependabot has open branches.** Check CI and the generated diff before any merge.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone, steps 58 to 64 included.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Legal items, still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. **Phase 5.3b** is L1 on the server, then screens 14 and 15 and the Insights tab. The prompt follows in the reply.
