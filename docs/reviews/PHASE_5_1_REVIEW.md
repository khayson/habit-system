# Phase 5.1 review (rewards and freezes on the server; the 4.3c carry-overs)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-12
Scope: `d0aec8f..a1e8ac3` (22 commits, 54 files, +2,413 / −122). Read at code level: both migrations, `XpAwarder`, `RewardState`, `FreezeWallet`, `ProfileSetAutoFreeze`, `RewardsQuery` and `RewardsController` in full; the diffs of `PeriodCloser`, `LogDay`, `LogDelete`, `AccountService`, `MutationApplier`, `BootstrapService`, `EntityPresenter`, `HeatmapService`, the routes, `FreezeEvaluator::closePeriods` and `refundLateCompletion`; the fixtures `reward_state_entity.json` and `freezes_response.json` and the `user_entity.json` diff; the tests `FreezeTest`, `RewardMigrationsTest` and `RewardsConcurrencyTest` in full, `XpTest` (helpers and five of its eight tests), the names of `RewardEntitiesTest` and `RewardEndpointsTest`, the diffs of six existing test files (`AuthTest`, `ConcurrencyTest`, `OwnershipTest`, `PeriodCloserTest`, `SyncHardeningTest`, `SyncTest`, not `HeatmapTest`'s) and of `Pest.php` with `assertLedgersMatchCaches`; on the app side the diffs of `conflicts.dart`, `conflict_review_screen.dart`, `sync_provider.dart`, `edit_habit_screen.dart`, the ARB, the e2e tool, and the added bodies in `conflict_review_screen_test.dart`, `conflict_resolution_test.dart` and `sync_provider_test.dart`; the doc diffs. I did not read the bodies of `RewardEntitiesTest` and `RewardEndpointsTest`, `rewards_response.json`, the bootstrap fixture or the new mutants, I did not run any check, and the CI page shows an overall result and job durations, not per-job results.

## 1. Verdict

**Phase 5.1 is accepted.** XP and the freeze wallet are on the server as asked: one entitlement per habit-day, one ledger per wallet, one writer for the cached numbers, one spend pass per user in A8 order, a refund that happens once, and `reward_state` as its own read-only entity so profile edits never conflict with a check-in. Every gate row has a test. Two Low findings and four Info notes ride in the next prompt's Part 0 (the first two are small server and docs changes). One sentence in the docs needs your word (section 5, question 2). Nothing blocks the next phase.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `a1e8ac360eb7f439ce104a2b3031e2ed181a7898` (the packet's `a1e8ac3` is its prefix). 22 commits; the first is `99dbc95`, and `PHASE_4_3C_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Run 38252602568 on `a1e8ac3`: success, push, 3m43s: api 1m38s, docker-compose 6s, app 3m39s, e2e 1m11s. The page shows only the overall result |
| Test counts | From the packet: Pest 633 (628 passed, 5 skipped), Flutter 665 to 671. The only skip marker I found is `markTestSkipped` in `AvatarPipelineTest` (it needs `/proc`); I did not check which five are skipped |
| Mutation check | From the packet: 45 mutants, 44 killed, 1 survived (the wallet re-offering periods before its watermark); `ff9e74d` adds a test, and the packet says the mutant was applied by hand, the test failed, and the full script was not re-run. `mutants.php` gains 57 lines. I did not run any of it |
| Prompt coverage | Parts 0 to 9 are all present: carry-overs, docs (A39 to A42 and the plan split), fixtures first, two migrations, XP, freezes, endpoints, tests, e2e scenario, mutation-check, packet |
| Migrations | `xp_entitlements` (UNIQUE(habit_id, log_date), amount = 10, state and revision CHECKs), `xp_ledger` (delta in (10, −10), UNIQUE(entitlement_id, entitlement_revision)), `freeze_ledger` (CHECK by kind, UNIQUE(user_id, source_key)), `freeze_usage` (UNIQUE(habit_id, period_key), a CHECK tying state to the refund columns), `user_freeze_policy_versions`, `reward_version`, `protected_in_streak`, `freeze_closed_through`. Both have a working `down()`. `RewardMigrationsTest` seeds a user, habit and log before each migration, checks they survive, and checks the constraints refuse a duplicate habit-day, a +20 delta, a duplicate source key, a −2 spend, a +3 grant and a balance of 3. `MigrationRollbackTest` loops over the migration files (lines 35 to 46); I did not run it |
| One writer | `RewardState::apply` is the only code that changes `users.xp` and `users.freeze_balance`: one `UPDATE … RETURNING`, `reward_version` +1, and `reward_state` journaled in the caller's transaction. A zero-delta audit row never goes through it |
| XP hook | `LogDay::write` (reached by `set_value` and by `increment`) and `LogDelete` call `XpAwarder::award` inside the mutation's transaction. `award` returns at once when completion did not change, so a day completed before Phase 5 earns nothing until it changes; otherwise it locks the entitlement row, applies `XpRules::transition`, writes the ledger row, and moves the cache. The tests cover the +10/−10/+10 toggle (three ledger rows, entitlement revision 3), crossing by increment, a partial value, delete, a pre-5 day, a backdate, a not-due day and a replayed mutation id |
| Freezes | Signup grant in the registration transaction; monthly grant first in `closeUser`, then one `closePeriods` call over every habit's newly closed misses, then usages with `protected` set, then each habit's streak is recomputed; a late completion refunds once through `refreshHabit`. `spend` passes refunded usages as already used, so a refunded period never spends again. Tests: two failures and one token (the longer streak wins, though its id sorts last), a failed week costs one, an open period never spends, opt-in is not retroactive, opt-out stops spending, refund at balance 1 (+1) and at balance 2 (a zero `cap_reached` row, and a second edit refunds nothing), a miss that closed with an empty wallet is never rescued by a later grant, and two real processes racing to grant and spend once |
| Entities | `reward_state` is journaled with its version, bootstrapped on the first page only, and listed in `READ_ONLY_ENTITIES`; the user entity and `/me` lose the five fields (fixture `never` list, AuthTest assertions); `habit_progress` gains `protected_in_streak`. `profile.set_auto_freeze` needs `base_version`, acknowledges an identical state with no bump and no policy row, and writes the policy at the server clock, never `occurred_at` |
| Endpoints | `GET /rewards` and `GET /freezes` sit under `auth:sanctum` and `throttle:api`; limit 1 to 50, default 20; keyset on (created_at, id) with a cursor bound to the user (`SyncCursor::decode($cursor, $userId, $type)`); a bad cursor or limit is 422. Names of the tests: shape, three-page paging, owner isolation, bad cursor, the largest limit, the xp.json levels |
| Heatmap | The fix reads a closed week's stored row (the lookup now starts six days before the window). The packet says the new test failed on the old code with seven `missed` cells; I did not run it on the old code |
| Existing tests changed | AuthTest, ConcurrencyTest, OwnershipTest, PeriodCloserTest, SyncHardeningTest, SyncTest: each change follows from the new journal rows or the removed fields (for example `['user', 'reward_state', 'habit', 'reward_state', 'habit_log', 'habit_progress']`). The H2 query bound rises from 5 to 6 with a comment saying why |
| Carry-overs | L1: `19` builds an empty Scaffold until the habit detail has a value; the test pumps 12 frames and asserts "Discard this change" never appears. L2: one `conflictKindOf(code, entity)` serves `_conflictOf` and `reviewable`; a data test and a widget test cover a profile and a reminder row. L3: `reviewableFor` and `outboxRow` live in `ConflictQueries` and the drift import left the editor screen. Notes a, d and f have tests; b, c and e do not (deviation 7). The connectivity guard shares one `_syncInBackground` with the debounce; its test closes the database under the engine. By reading, the L1 test would have caught the old behaviour; I did not run it on the old code |
| e2e | The new `rewards` scenario: device B holds one `reward_state` in `opaqueEntities` with `xp` 10 and `freeze_balance` 2 |
| Legal | `docs/legal/privacy.md` line 31 already lists "protected days, points, level and freeze balance", so "no change" holds |

## 3. Findings

**L1 · Low · GET /freezes joins the usages with no index and no user filter**
`RewardsQuery::freezes` does `LEFT JOIN freeze_usage u ON u.spend_ledger_id = l.id OR u.refund_ledger_id = l.id`. Migration 100012 declares no index on either column (and PostgreSQL does not index a referencing column by itself), and the join does not restrict `u` to the caller. By reading, each page can scan every user's usages. The same two foreign keys cascade on delete, so deleting a ledger row (Phase 6 account deletion) has to find its usages without an index. I did not run EXPLAIN. Fix: a new migration `2026_10_12_100013` adding an index on each column (a rollback test and an upgrade test, as for the others), and `u.user_id = l.user_id` in the join. Test: both indexes exist; the existing paging tests stay green.

**L2 · Low · A41's text names the wrong table and leaves out the watermark**
My A41 text said `freeze_usages`; the table is `freeze_usage` (the spec's name, which the migration comment points out). The text also does not mention `users.freeze_closed_through`, which decides what "newly closed" means: a period offered to the wallet is one that ended after the watermark, and the watermark moves to yesterday after each pass. Fix in docs: the table name, and one sentence for the watermark. A41 should also say what the test pins: a miss that closed with an empty wallet is never rescued by a later grant.

**I1 · Info · A catch-up pass can understate a habit's streak at risk**
`candidates()` counts a habit's run from evaluations that do not yet include the protections the same pass grants. If the closer skipped two days, habit A's second missed day reads 0 at risk (its first miss is still unprotected in that count), so the A8 order across habits can give the last token to a habit with a shorter streak. It needs a gap of at least two days; the scheduler runs every 5 minutes. Note it in A41, or fix by running the pass one day at a time.

**I2 · Info · Each close evaluates every habit twice**
`candidates()` and `refreshHabit()` each run `evaluate()` for every habit and each reads the habit's active usages (the packet reports the CPU growth). The query count per habit is constant, so the H2 test is right. Share one evaluation inside `closeUser` before the Phase 7 load test; no change now.

**I3 · Info · Two policy rows with the same `effective_at` have no defined order**
`FreezePolicy` sorts versions by `effective_at` only and `policy()` reads them with no ORDER BY. A user (or two devices) toggling on and off inside the same timestamp tick would make "which was in force" depend on the row order. Read them ordered by (effective_at, id). I saw one stored value (`2026-05-22 16:00:00`) and did not check the column's precision.

**I4 · Info · reward_state is journaled before the log in the same commit**
The tests assert that order (`['reward_state', 'habit_log', 'period_evaluation', 'habit_progress']`). It is harmless: the app stores it opaquely, and the numbers belong to the same commit. Keep it in mind when the app starts reading `reward_state` (5.2): it must not assume the log came first.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 `freeze_usage` (singular, with `definition_version`, `used_on`, `reconciled_at`, `refund_ledger_id`), `users.reward_version`, `users.freeze_closed_through` | Accepted. The singular name is the spec's; the watermark is needed (`computed_through` moves on every log write without a spend pass). A41 gets the watermark: L2 |
| 2 The wallet marks a user stale only if they have a habit | Accepted. See answer 3 |
| 3 Eight existing tests updated; the H2 bound 5 to 6 | Accepted. Each change follows from the new rows, and the comment says why the bound moved |
| 4 `assertMatchesContract` accepts `{{time}}` and `{{cursor_or_null}}` | Accepted |
| 5 An empty `?cursor=` is the first page | Accepted (the same as bootstrap) |
| 6 The 99 XP case skips the ledger check | Accepted: XP moves in tens, so 99 is only reachable through the cache |
| 7 Notes b, c and e from 4.3c have no tests | Accepted, no action. They are polish, and the packet said so |
| 8 and 9 Style commits; `startCloser` and `finishProcess` helpers | Accepted |
| 10 `docs/legal`: no change | Accepted (line 31 of `privacy.md`) |

## 5. Open questions (answered)

1. **Should 5.2 switch the detail screen's `protectedInStreak` to the server's `protected_in_streak`?** Yes, and the local heuristic goes. A search of `app/lib` for `protectedInStreak` finds only the detail view's getter and its one use, so the local `habit_progress` table has no column for it and `progressRow` does not read it; the app part adds a nullable column with an upgrade test. A stored week colouring each of its due days with the server's status is the intended reading.
2. **Not-due days.** The packet, A40's heading and BUILD_PLAN say you confirmed that a not-due day earns XP "on 2026-10-12". I did not see that confirmation (my prompt marked it as awaiting your word). If you did confirm it, nothing changes. **If you did not, tell me**, and the next prompt rewords both lines to "default applied; Khay Studios to confirm". The behaviour is the same either way.
3. **Is it acceptable that a month with no closer run has no grant row?** Yes, with one correction to the packet's reading: a user with at least one habit is queued every day by the stale check (`walletStale`: the watermark is older than yesterday), so an inactive user still gets their month row. Only a user with no habits gets none until the first habit, whose first close tops the wallet up to 2.

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 45 of `docs/DEVICE_GATE.md`.** Phase 4 is built but unproven on a phone, and Phase 5 will add its own steps.
- **A timezone change can move the watermark backwards** (the packet's risk). A double spend is blocked by the unique usage key, but a miss that was skipped for lack of a token could be offered again. There is no test for it.
- **"Newly closed" is the rule.** A miss that closes with an empty wallet stays unprotected even after the next grant (a test pins it). The copy on screen 17 must not promise otherwise.
- **The local dev database has migrations 100011 and 100012 applied** (the packet) and 37 dev accounts that match their ledgers. Nothing from the dev database may reach a commit.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **My 4.1 review still carries one wrong sentence** (the engine lines 370 to 371 were inside the bootstrap transaction); the 4.2a review has the correction. I can issue a corrected copy if you want it.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone. The next part is app work, so a phone result would help before it lands.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Reply to question 2 above if you did not confirm the not-due-day default.
4. Legal items, still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
5. **Phase 5.2 is the app side of rewards and freezes** (screens 06, 16, 17, 35, Today's XP chip and summary line, the profile line, the auto-freeze switch, the 12 footer), swapped ahead of insights, which becomes 5.3, because it consumes what 5.1 built. The prompt follows in the reply.
