# Phase 5.2c review (the completion screens 06 and 35, and the engine's ack watch)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-21
Scope: `98d9bec..06f07e6` (13 commits, 29 files, +1,517 / −29; nothing under `api/`). Read at code level: `ack_watch.dart`; the engine's `_apply` change; `completion_wait.dart`; `LocalWrite.completeAfter` and `LocalView.dayComplete`; `completion_screen.dart`; the changes to `amount_entry_screen.dart`, `timer_screen.dart`, `profile_screen.dart`, `account_context.dart`, `sync_provider.dart` and the router; the ARB additions; the fixture `ack_xp_delta_wire.json` and its registration; the `completion` e2e scenario and the harness changes; the `SPEC_AMENDMENTS` (A46), `BUILD_PLAN` and `DEVICE_GATE` diffs. Read in part: `completion_flow_test.dart` (the harness and the first test in full, the rest by name). Not read: the generated l10n files. I compared the strings with design screens 06 and 35 (rendered from the PDF). I did not see the four screenshots; they are in Claude Code's scratchpad. I did not run any suite.

## 1. Verdict

**Phase 5.2c is accepted.** The completion screen opens only for a save that left the day complete, only for an accepted ack that carries `xp_delta` above zero, and only while the person is still on the save screen. Every other path returns as before. The Level card reads the local `reward_state` live, so a late `reward_state` page updates it. Two Low findings and three Info notes ride into the next prompt. Nothing blocks 5.3.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `06f07e619217ab08ab77df43dde6a176951a70ef` (the packet's `06f07e6` is its prefix). 13 commits; the first is `644c23e`, and `PHASE_5_2B_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Run 39139611148 on `06f07e6`: success, push, 4m01s. The page shows only the overall result and the job times |
| `api/` untouched | Nothing under `api/` differs from `98d9bec`, so Pest (646) and the mutation check (46 of 46) stand, and skipping the mutation check is right |
| Test counts | From the packet: Flutter 723 to 754 (+31); Pest unchanged at 646. The packet's named groups (12 flow tests, 4 complete-after, 3 Freezes row) are in the diff; I did not total the ack-watch and fixture cases to exactly 31 |
| Prompt coverage | Parts 0 to 8 are present: the review committed first, the carry-overs (step 55 wording, the Freezes row), A46, the fixture, `AckWatch`, `completeAfter`, the screen, the flow, DEVICE_GATE 58 to 64, the e2e scenario, the packet |
| Wire fixture | `ack_xp_delta_wire.json` (Dart suite): `+10`, `−10`, no key, the string `"10"` (read as none), and `0` (kept as 0). The completion rule then keeps only an accepted ack with a delta above zero |
| `AckWatch` | `AckSummary.fromAck` keeps final statuses only (accepted, conflict, rejected); a non-integer `xp_delta` becomes null. `publish`, `known`, `waitFor` and `firstOpening` work on a bounded map of the last 50. The engine collects the summaries inside the apply transaction and publishes after the commit, and a rolled-back transaction publishes nothing (a test for each) |
| Wait rules | `CompletionWait.start` returns null when the write did not leave the day complete or the account is offline. Otherwise it syncs at once, runs one more sync when the mutation is still pending after the first, and waits up to 6 s. Backoff, rate limit, failure, pause and logged-out states leave at once. The result is a number only for an accepted ack with a delta above zero |
| One opening | `firstOpening(mutationId)` is checked before `pushReplacement`, so a mutation opens the screen at most once; Back cancels the wait, and a late ack finds no listener (a test) |
| `completeAfter` | Computed inside the write transaction through `LocalView.dayComplete`, which shares Today's own completion rule. No second rule was written |
| Screen | Header "That counts." with its subtitle, the check, "{habit} complete", "{value} logged today", the chip "+{n} XP" from the ack, a Level card from `RewardsView` and `LevelProgress`, "Back to today", the footer. No bottom bar. A missing `extra` goes to Today. The fade is 200 ms and off under reduced motion |
| Design match | Rendered from the PDF: the header and its subtitle, the heading shape, the chip, the card ("Level 13" left, "1,250 XP total" right, "50 / 100 XP toward Level 14"), "Back to today" and the footer all match word for word. The prose line under the heading cannot be derived from data; see deviation 2 |
| Profile row | `freezesRowLine` shows the count alone until the profile loads. My 5.2b L2 is fixed with a failing test first |
| e2e | The `completion` scenario against the real server: +10, a further increment (none), below target (−10), again (+10); the second device nets +10. 24 scenarios in the packet |
| Legal | No new data is collected; "no change" holds |

## 3. Findings

**L1 · Low · The wait also starts when the day was already complete**
`completeAfter` is true whenever the day is complete after the write, so a further increment on a day that was already complete (and had already paid its XP) syncs and waits for an ack that will never carry `xp_delta`. It ends when the ack arrives, so the cost is one round trip and a "Confirming…" flash, up to 6 s on a slow link. Fix: start the wait only when the write moved the day from not complete to complete, or when it joined a pending row for that habit-day that has not been acknowledged yet (that row's ack is the one that will carry the XP). Compute "was complete before" inside the same transaction. A failing test first: an increment on an already complete, synced day leaves at once and forces no sync.

**L2 · Low · The amount screen's preview moves under the person while confirming**
The packet's open question. While the screen waits, the preview reads "After saving 4 / 2 L" because the saved total has already updated beneath it. Freeze it: keep the preview text from the moment of the save while the wait is live (or hide the preview line during "Confirming…"; prefer freezing, so the layout does not jump). One widget test: with the wait live and the local total changed, the preview text is unchanged.

**I1 · Info · The flow tests run the real engine in the widget test's fake zone**
They pass by driving a fixed number of rounds on fake time. A slow CI machine does not change fake time, so the risk is lower than the packet fears, but a change to the engine's scheduling would break all twelve at once. If they ever flake, the first thing to look at is the number of rounds, not the 6 s.

**I2 · Info · "{value} logged today" is a data line, not the design's prose**
The design's line under the heading is a sentence of its own ("A moment for yourself" belongs to the subtitle). It cannot be built from the data, so the app shows what is known. Accepted (A5-complete-line).

**I3 · Info · A late ack never opens the screen, by design**
A slow save that times out leaves as today and the person never sees 06 or 35 for it, though the XP still lands. That is the A46 rule, and the Level card on Today is the record.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 "That counts." and its subtitle are in the design though my prompt did not list them | Accepted, and it was my mistake: my 5.2b review said the heading was "{habit} complete" and not "That counts.". The design has both (the header and the heading). Claude Code built what is drawn. The committed 5.2b file stays unchanged; this paragraph is the correction |
| 2 `ASSUMPTION(A5-complete-line)`: "{value} logged today" | Accepted (I2) |
| 3 `ASSUMPTION(A44-offline-return)`: offline saves return at once | Accepted. Nothing can be confirmed offline, and A44 says the app shows confirmed numbers only |
| 4 The duration screenshot comes from the amount screen; the timer path is covered by a widget test | Accepted; gate step 62 covers the timer on a phone |
| 5 The later-response test sends the `reward_state` in the next response, not with a pull limit of 1 | Accepted; the app's limit is fixed at 200 |
| 6 `testAccount` gained a `transport` option; no `fake_async` package | Accepted |
| 7 The formatter slip did not recur | Accepted. The process rule held |
| 8 Local only: dev API and PostgreSQL restarted; a "Meditation" habit added to the screenshot account | Accepted. None of it is in a commit |
| 9 `docs/legal`: no change | Accepted |

## 5. Open questions (answered)

1. **Should the preview freeze while confirming?** Yes, freeze it (L2).

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 64 of `docs/DEVICE_GATE.md`.** Steps 58 to 64 are the first that need a real network delay; the emulator's artificial delay is not the same as a phone on a weak mobile signal.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **A timezone change can move the freeze watermark backwards** (from 5.1). A double spend is blocked by the unique usage key. No test.
- **"Newly closed" is the rule.** A miss that closes with an empty wallet is not rescued by a later grant, and no screen may say it is.
- **My 4.1 review still carries one wrong sentence** (the engine lines 370 to 371 were inside the bootstrap transaction); the 4.2a review has the correction. I can issue a corrected copy if you want it.
- **Dependabot has open branches** (larastan, pest, analyzer, connectivity_plus, drift). Check CI and the generated diff before any merge.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone, steps 58 to 64 included. Give the gate account a city so step 49 shows the with-place line.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Legal items, still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. **Phase 5.3 is insights:** `GET /insights` on the server (the domain calculator already exists) and screens 14 (A week of progress) and 15 (Your consistency). The prompt follows in the reply.
