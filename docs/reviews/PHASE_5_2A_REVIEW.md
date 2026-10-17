# Phase 5.2a review (the 5.1 follow-ups, `xp_delta`, and the reward numbers on the app)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-17
Scope: `a1e8ac3..1e12ed7` (17 commits, 48 files, +1,912 / −67). Read at code level: every server change under `api/app` (`HandlerResult`, `LogDay`, `LogDelete`, `ProfileSetAutoFreeze`, `MutationAck`, `MutationApplier`, `FreezeWallet`, `RewardsQuery`, `XpAwarder`) and migration `100013`; the new and changed server tests (`AckXpDeltaTest`, the I3 test, the L1 migration test, the new mutant, the `{{date}}` placeholder); every contract-fixture change; on the app, `app_database.dart` (the v9 to v10 upgrade), `entity_codec.dart`, `rewards_view.dart`, `habit_detail_view.dart`, the engine's apply dispatch and `_upsertRewardState`, the Today and Profile changes, the ARB keys, the e2e scenario, and the diffs of twelve test files (three PHP, nine Dart); the diffs of `SPEC_AMENDMENTS.md`, `BUILD_PLAN.md` and `DEVICE_GATE.md`. Not read: the generated files (`app_database.g.dart`, `lib/l10n/generated`). I did not run any suite.

## 1. Verdict

**Phase 5.2a is accepted.** The follow-ups from the 5.1 review are done, the ack carries the amount the server awarded, and the app now holds the reward numbers in a typed table that it only ever reads. Today and Profile show the confirmed numbers, the waiting sentence says what happens to them, and the 12 footer no longer guesses. Three Low findings (stale text and a test gap) and four Info notes ride into the next prompt. Nothing blocks 5.2b.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `1e12ed75f66c260a30b2dfd120e7e569df14af1c` (the packet's `1e12ed7` is its prefix). 17 commits; the first is `660e216`, and `PHASE_5_1_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Run 39045810023 on `1e12ed7`: success, push, 3m43s: api 1m32s, docker-compose 4s, app 3m40s, e2e 1m10s. The page shows only the overall result and the job times |
| Test counts | From the packet: Pest 646 (641 passed, 5 skipped), Flutter +687. I counted the additions from the diffs and they add up: Pest 633 + 13 (five `ack_xp_delta` cases, two single tests, four `next_refill_on` cases, the I3 test, the L1 test) and Flutter 671 + 16 (one upgrade, four in the derived suite, one fixture, three footer cases, three Profile, four Today) |
| Mutation check | From the packet: 46 mutants, 46 killed. The one new mutant removes `xpDelta:` from the accepted ack and names `AckXpDeltaTest`. I did not run it |
| Prompt coverage | Parts 0 to 9 are present: the review committed first, docs, L1, I3, fixtures first, A43, the app tables, the lines, the footer, DEVICE_GATE, the e2e change, the packet |
| L1 | Migration `100013` adds both indexes; the join is now `u.user_id = l.user_id AND (spend_ledger_id = l.id OR refund_ledger_id = l.id)`. The migration test seeds a usage before the migration, asserts through `pg_indexes` that neither index exists, migrates, asserts both exist and the row survived |
| I3 | A new version's `effective_at` is the later of the clock and the user's latest version plus one second; `FreezeWallet::policy` reads `(effective_at, id)`. The test toggles on, off, on in one frozen tick and asserts strictly rising times and that the policy at the last time is on. The packet says it failed first with `1779988920 is greater than 1779988920` |
| A43 on the ack | `XpAwarder::award` now returns the delta (`null` when completion did not change or the transition moved nothing); `LogDay` and `LogDelete` pass it into `HandlerResult`; `accepted()` copies it into the ack; `toArray` drops a null (the filter keeps only `mutation_id`, `status`, `duplicate` when null), so the key is absent unless XP moved; `fromStored` reads it back, so a receipt written before this change has no key and decodes. The tests cover a complete, an undo, a partial write, a delete of a completed day, a duplicate replay, a day completed before Phase 5, and a receipt with the key removed |
| `next_refill_on` | Taken from `UserCalendar::timeline($userId)->localDateAt(clock->now())`, then the first of the next month, with December rolling the year. Cases: Los Angeles in May, December, 31 May evening (1 June in UTC), and Accra at the same instant |
| App tables | `reward_state` (id, five nullable ints, version, `extra`) and `habit_progress.protected_in_streak` as a column; schema 10. The upgrade adds the column only when `from` is 5 to 9 (an older database creates the table with it), creates `reward_state` for every `from < 10`, lifts an integer `protected_in_streak` out of `extra`, and moves decodable opaque `reward_state` rows (the table is new, so the version rule holds) |
| Apply path | `_applyChange` routes `reward_state` to `_upsertRewardState`, which ignores a lower version and otherwise upserts. Pulls and bootstrap share it. A wrong-typed known field throws inside `_guarded`, so the item is kept as `undecodable:reward_state` and the confirmed row stays; a test pins that |
| The lines | `RewardsView` returns null when the row, `xp` or `level` is missing, so no line shows. Today: `Semantics(container: true, excludeSemantics: true)` with its own label, "1,240 XP, Level 13". Profile: four cases (with or without confirmed numbers, with or without a place). The waiting sentence and the queue's offline card carry "Rewards update after syncing." |
| 12 footer | `protectedInStreak` is now `progress?.protectedInStreak ?? 0`; the heuristic is gone. Three cases (1, 0, absent) each include a protected evaluation that would have fooled the old code |
| e2e | The `rewards` scenario asserts one typed row (xp 10, balance 2) and no opaque row whose type ends in `reward_state` |
| Docs | A41 gets the table name, the watermark sentence, the empty-wallet sentence and the catch-up caveat; A43 and A44 are in section 15; DEVICE_GATE gets steps 46 to 50 with result rows |
| Legal | No new data leaves the device and the server already lists points, level and freeze balance, so "no change" holds |

## 3. Findings

**L1 · Low · The `reward_state_entity.json` description is stale**
It still says "The client stores it opaquely until Phase 5.3". The client types it since 5.2a, and the same file now lists `dart` in `suites`. Fix: one sentence.

**L2 · Low · BUILD_PLAN line 86 still says the heuristic goes "in Phase 5"**
"`protected_in_streak` joins `habit_progress` in Phase 5; the client's heuristic for the 12 footer goes then." It has gone. Reword it as done in 5.2a.

**L3 · Low · Two branches of the v10 upgrade have no test**
The upgrade test covers the happy path and an unrelated opaque row that stays. Not covered: a `protected_in_streak` that is not an integer (it should stay in `extra`) and an opaque `reward_state` that does not decode (it should stay opaque). Both are three-line cases.

**I1 · Info · A burst of policy toggles runs ahead of the clock**
With I3 each toggle in the same second lands one second after the previous, so a batch of N toggles ends N − 1 seconds ahead of the server clock. Harmless: opting in is prospective, the order is stable, and a client can only send what one batch allows. No action.

**I2 · Info · A44's bar sentence names the span, not the fill**
"Width = next_level_threshold minus (xp minus progress_into_level)" is the size of the level in XP. The bar fill is `progress_into_level ÷ that span`, clamped to 0 to 1, with a guard for a span of zero or less. The label "50 / 100 XP toward Level 14" uses the same span and `level + 1`. This is display arithmetic on three confirmed numbers, not a rule. The next prompt rewrites the sentence and keeps the arithmetic in one tested function. If levels ever skip, the server must send the next level's number.

**I3 · Info · No test sends `reward_state` ahead of its log in one pull (carried from 5.1's I4)**
The apply path does not depend on order, and a test shows an older version is ignored, but nothing proves it. The next prompt adds one cheap Dart test. Related for 5.2c: a check-in's ack and its `reward_state` change normally arrive in the same page, and `_apply` writes the acks and the page's changes in one transaction. If the changes span pages, the second page arrives a moment later. The completion screen must read the numbers live.

**I4 · Info · `next_refill_on` uses the calendar in force today**
A timezone change that takes effect next month could move the real grant day by one day (the packet's risk). Accepted. Screen 17 shows the date exactly as the server sent it and never works one out.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 Three fixtures (`log_backdate_payload`, `ack_restored`, `ack_delete_natural_key`) gain `xp_delta` | Accepted. Those writes do move XP and the fixtures compare keys exactly. The Dart suite already consumes them, so 5.2c can read the key from the same files |
| 2 `assertMatchesContract` gains `{{date}}` | Accepted; `freezes_response.json` uses it |
| 3 A separate screen-reader string for Today's line | Accepted; it keeps "·" out of the speech |
| 4 The spike test pins schema 10; the architecture test registers the new Dart fixture consumer | Accepted |
| 5 A formatter run rewrote `app_database.g.dart` once; build_runner's output was restored before the commit | Accepted. Working rule 5 holds (no generated file edited by hand) |
| 6 Local only: dev PostgreSQL and API restarted on 8001; migration 100013 applied to the dev database | Accepted. None of it is in a commit |
| 7 `docs/legal`: no change | Accepted |

## 5. Open questions (answered)

1. **The Profile screenshot has no place. Is that enough?** Yes, no re-take. The with-place line "Portland · Level 13 · 1,250 XP" is pinned by a widget test. Device-gate step 49 names both variants, so the phone check covers whichever your account has.
2. **Hide XP and level while a sync conflict is open?** No, leave them shown. They are the server's confirmed numbers and a conflict is about one habit-day's unsent edit. Hiding them would make a conflict look like it touches your progress.
3. **The not-due-day default.** Closed. You chose "Yes, same XP" in the Claude Code session on 2026-10-12, so the wording in A40 and BUILD_PLAN is right as it stands. (I did not see that choice when I wrote the 5.1 review.)

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 50 of `docs/DEVICE_GATE.md`.** Phase 5 now has five steps of its own. Phase 5.2b adds the first screens that change data (the auto-freeze switch), so a phone result matters more from here.
- **A timezone change can move the freeze watermark backwards.** A double spend is blocked by the unique usage key, but a miss skipped for lack of a token could be offered again. No test.
- **"Newly closed" is the rule.** A miss that closes with an empty wallet stays unprotected after the next grant. The copy on screen 17 must not promise otherwise.
- **The completion flow (5.2c) waits on an ack.** A slow network, a late page, or leaving the screen early must never open screen 06 or 35 after the fact. That is a test, not a hope.
- **Dependabot has open branches** on `origin` (larastan, pest, analyzer, connectivity_plus, drift). They are not part of any phase. The drift bump can change generated code, so check CI and the generated diff before any merge.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **My 4.1 review still carries one wrong sentence** (the engine lines 370 to 371 were inside the bootstrap transaction); the 4.2a review has the correction. I can issue a corrected copy if you want it.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone, now including steps 46 to 50.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Legal items, still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. **The old 5.2b is split in two** so each review stays readable. **5.2b** is screens 16 and 17, the services behind them, the auto-freeze switch and the links in (Profile and the 12 footer). Without the switch nobody can turn auto-protect on, so it comes first. **5.2c** is the completion screens 06 and 35 and the engine's ack watch. Insights stay 5.3. The 5.2b prompt follows in the reply.
