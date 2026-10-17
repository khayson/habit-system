# Phase 5.2b review (screens 16 and 17, the auto-freeze switch, and the ways in)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-17
Scope: `1e12ed7..98d9bec` (19 commits, 44 files, +2,867 / −23; nothing under `api/`). Read at code level: `RewardsService` and `reward_pages.dart`; `setAutoFreeze`, the `ProfileView` overlay, and the engine's rebase-once change; `LevelProgress`; `reward_history.dart`, `ledger_pager.dart`, `ledger_list.dart`, `progress_screen.dart` and `freezes_screen.dart` in full; the router, shell, Profile, habit-detail footer and queue-label diffs; all ARB additions; the new and changed tests (`auto_freeze_test`, the migration and derived-suite cases, the queue, footer and Profile cases, the harness and fake-server changes, the e2e scenario); the fixture, `BUILD_PLAN`, `DEVICE_GATE` and `SPEC_AMENDMENTS` diffs. Read in part: `reward_screens_test.dart` (the switch, needs-a-look, text-scale and entry-point cases in full, the rest by name) and `rewards_service_test.dart` (one loop in full, the rest by name). Not read: the generated l10n files. I compared the new strings with the design sheet (screens 16 and 17, rendered from the PDF). I did not see the four screenshots; they are in Claude Code's scratchpad. I did not run any suite.

## 1. Verdict

**Phase 5.2b is accepted.** Screens 16 and 17 are built as drawn, with the numbers read from the local `reward_state` and only the history coming from the network. The auto-freeze switch works through the outbox like every other write, and the one engine change (a second conflict is the user's to see) is small and tested. Two Low findings and four Info notes ride into the next prompt. Nothing blocks 5.2c.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `98d9bec26d769a0885e146bbc4f2d685a88ba929` (the packet's `98d9bec` is its prefix). 19 commits; the first is `13617a0`, and `PHASE_5_2A_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Run 39062664599 on `98d9bec`: success, push, 3m47s: api 1m42s, docker-compose 6s, app 3m42s, e2e 1m31s. The page shows only the overall result and the job times |
| `api/` untouched | `git diff --name-only 1e12ed7..HEAD -- api` prints nothing, so Pest (646) and the mutation check (46 of 46) stand as they were, and skipping the mutation check is right |
| Test counts | From the packet: Flutter 687 to 723. The additions add up from the diffs: screens 12, service 9 (five rewards cases with three malformed, three freezes, one API error), `LevelProgress` 4, auto-freeze 6, queue 2, migration 1, derived suite 2 (the two pull limits). Total 36 |
| Prompt coverage | Parts 0 to 8 are present. Part 1 a to f: the fixture sentence, BUILD_PLAN (5.2a done, 5.2b and 5.2c split), the two upgrade cases, the A44 bar text, A45 as written, and the reward-state-before-its-log test on one page and across pages |
| Service | `RewardsService` sends `limit` and `cursor` through `ApiClient`; `fromJson` requires the fields the screens use and keeps `reason` and `kind` as strings; any decode failure becomes `AppException` with code `unexpected_response`. It never touches the database. The pages are not stored |
| Switch, data layer | `setAutoFreeze` follows `updateProfile`: a pending row coalesces (latest payload, base kept), else a new row on the user entity with the confirmed user version. `ProfileView` overlays the latest unacknowledged `profile.set_auto_freeze` (any state in `unacked`, so a needs-attention row still shows the intent) and never writes the confirmed row; a test checks the confirmed payload stays `false` while queued |
| Engine | `_rebasesOnce = {profile.set_timezone, profile.set_auto_freeze}`; the same code path re-sends once with a new mutation id on the named version. The test with the engine change stashed failed (the packet); the second-conflict test asserts needs-attention, `conflictKindOf` is `other` and `reviewable` is false. The send selection allows one row per entity per request, so an edit and the switch queued together never conflict with each other (the test and the e2e both cover it) |
| Screen 16 | Level, XP and the bar from `RewardsView` (offline-safe); `LevelProgress` holds the arithmetic and the bar is excluded from semantics while its label carries the meaning. Recent XP: one `GET /rewards` on open, loading, a neutral error with Try again, Show more, and a failed later page keeps the rows. The page's own `xp` and `level` are ignored. Rows: the habit name from local habits ("A habit" when not found), Today / Yesterday / a short date from the account calendar, "completed {value}" only when the local log exists and meets the target, one merged label per row |
| Screen 17 | Balance from `reward_state`; cap and refill from `GET /freezes`, held in memory; before that answers, "{balance} freezes" and no refill line. The switch row is one 44 px target with `toggled`, label and hint, and its own queued and needs-attention notes. History rows follow the prompt's copy; a `period_key` other than `d:` or `w:` reads "period" |
| Entry points | Two Profile rows (`push`, so Back returns to Profile) and the 12 footer as a button with a chevron; the footer test asserts a height of at least 44 and that it opens 17 |
| Design match | Rendered from the PDF and compared: 16's title, LEVEL 13, XP, the bar label, Recent XP rows and the footer; 17's title, subtitle, "1 / 2 freezes", "Next refill: 1 June · up to 2 total", the switch row, "Usage history", the row "Meditation · 20 May" with "1 freeze used · daily period protected" and "−1", and the note, whose title and body match word for word |
| e2e | New `autofreeze` scenario: A turns it on and B pulls it; opposite toggles end with both devices on the value that reached the server last and nothing needing a look; an edit and the switch queued in one session both reach `/me`. 23 scenarios in the packet |
| Legal | Reads only; `auto_freeze` was already stored. "No change" holds |

## 3. Findings

**L1 · Low · Gate step 55 and the e2e comment say "the later choice"**
The rule is the choice that reaches the server last: the stale device's conflict is re-sent on top of the other. Taps and syncs can come in different orders (A taps first and syncs last, and A wins even though B tapped later). For a switch that is fine, but the step should say what a tester will actually see. Reword step 55 to "both end on the choice that reached the server last", and the e2e comment the same way.

**L2 · Low · The Profile Freezes row can say "auto-protect off" before it knows**
`profile?.autoFreeze ?? false` reads as off while the `ProfileState` stream has not emitted, so for a moment a user with it on is told it is off. Show the balance alone until the profile has a value. A failing widget test first.

**I1 · Info · The switch shows no "On" or "Off" words**
The design draws none, and invariant 12 asks for a symbol or text, never colour alone. The thumb position is the symbol, the `toggled` flag is the screen-reader text, and Profile's row says "auto-protect on" or "off" in words. Accepted, no change. If gate step 57 shows it is hard to tell at a glance, a check mark in the thumb is the smallest fix.

**I2 · Info · Two quick taps can write the same value twice**
`toggle` uses the state from the last build (`!on`), and the stream re-emits a moment after the write, so a second tap in that window writes the same choice again. The outbox coalesces it and nothing breaks; the person sees one change where they tapped twice. No action. If it ever matters, flip inside `setAutoFreeze`'s transaction.

**I3 · Info · "From now on" starts when the change reaches the server**
A42 sets the policy time at apply, so a switch turned on offline protects periods that close after it syncs. The row says "Turning it on protects periods that close from now on." and the queued note says "It applies after syncing." Together they are honest. No action.

**I4 · Info · An open history list does not refresh on a sync**
The packet's risk. The balance does refresh (it is the local `reward_state`); the list is read once per visit. Accepted.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 16 and 17 sit inside the shell with Profile selected (my prompt said full screen) | Accepted, and it was my mistake: both screens draw the bottom bar with Profile selected. The design wins on how a screen looks. The routes stay `/rewards` and `/freezes`, Back is a `push` pop, and a test checks both |
| 1b No "On"/"Off" words | Accepted (I1) |
| 2 ASSUMPTIONs: `A5-progress-subtitle`, `A5-profile-rows`, `A11-prospective-line`, `A41-refund-row-copy`, `A41-grant-row-copy` | Accepted. The design shows only a spend row, so the refund and grant copy is new and stays neutral. The design's subtitle on 16, "After your meditation check-in.", is the 5.2c case (see next steps) |
| 3 `ledger*` string prefix; full month name with the year only when it differs | Accepted |
| 4 Harness `pullLimit` and `rewardsApi`; the fake server handles `set_auto_freeze`; `materialize` gains three placeholders | Accepted |
| 5 A formatter run rewrote `app_database.g.dart` in `915c205`; `789fc2b` restored it | Accepted, but this is the second phase in a row. History now holds a generated-file change in the middle. The next prompt asks for a process fix (format files by name) |
| 6 Local only: the screenshot account's policy row and watermark moved by SQL; the dev API runs on 8001 | Accepted. None of it is in a commit |
| 7 `docs/legal`: no change | Accepted |
| 8 Dependabot branches untouched | Accepted |

## 5. Open questions (answered)

1. **Should the switch also show "On" and "Off"?** No. See I1.
2. **The dev server's "Maximum execution time of 30 seconds" in Composer's class loader.** It predates this phase (14 and 15 October) and is a dev-machine matter, not a repository one. I cannot see your machine, so this is a guess: a cold autoloader scanned by antivirus on Windows is slow on the first requests. Running `composer dump-autoload -o` in `api/` and excluding the project folder from real-time scanning are the usual fixes. Nothing to commit. If it appears on the gate phone's dev server, retrying is fine.

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 57 of `docs/DEVICE_GATE.md`.** Phase 5.2b is the first phase where a screen writes reward-related data (the switch), so a phone result matters from here.
- **The completion flow (5.2c) waits on an ack.** A slow network, a late page, or leaving the screen early must never open screen 06 or 35 after the fact. That is a test, not a hope.
- **A timezone change can move the freeze watermark backwards** (from 5.1). A double spend is blocked by the unique usage key, but a miss skipped for lack of a token could be offered again. No test.
- **"Newly closed" is the rule.** The note on 17 says a real completion can return the token once; it does not promise that a miss closed with an empty wallet is rescued, and it must stay that way.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **My 4.1 review still carries one wrong sentence** (the engine lines 370 to 371 were inside the bootstrap transaction); the 4.2a review has the correction. I can issue a corrected copy if you want it.
- **Dependabot has open branches** (larastan, pest, analyzer, connectivity_plus, drift). Not part of any phase; check CI and the generated diff before any merge.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone, steps 46 to 57 included. Give the gate account a city so step 49 shows the with-place line.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Legal items, still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. **Phase 5.2c is the completion screens 06 and 35 and the engine's ack watch.** I rendered 06 and 35 from the design sheet for the prompt: the heading is "{habit} complete" (not the line I had in mind), with a value line, the "+10 XP" chip, a Level card ("Level 13", "1,250 XP total", the bar, "50 / 100 XP toward Level 14"), "Back to today" and "Missed days never erase what you have learned." The prompt follows in the reply. Insights stay 5.3.
