# Phase 4.3b review (amount entry, the timer screens, the Today cards; the 4.3a carry-overs; two reminder fixes from the phone)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-12
Scope: `af5b33e..a09cc1d` (the packet's range: 13 commits, 35 files, nothing under `api/` or `contract-fixtures/`) plus `a09cc1d..08f73d9` (two commits that landed after the packet, 4 files). Read at code level: the diffs of `local_mutation_service.dart`, `local_view.dart`, `habit_type_ui.dart`, `today_screen.dart`, `habit_detail_screen.dart`, `reminder_scheduling.dart`, `notification_scheduler.dart`, the date-format screens, `app_en.arb`, `ci.yml`, `api-serve.ps1`, `SPEC_AMENDMENTS.md`, `BUILD_PLAN.md`, `DEVICE_GATE.md`; `amount_entry_screen.dart` and `timer_screen.dart` in full; `useMine` and the timer writer functions in full; the M1 tests, the 4.3b registry tests, the reminder tests and the timer finish and discard tests. For 4.3c I also read `needs_attention.dart`, the queue row code and `EditBlockedNote`. I did not read the bodies of the Today-card and amount-screen widget tests (names only), the generated l10n files or the screenshots (they are on your machine), and I did not run any check. The CI page shows an overall result and job durations, not per-job results.

## 1. Verdict

**Phase 4.3b is accepted.** The amount screen is a thin, honest layer over `incrementLog` (nothing is written until Add, a refused amount keeps the typed text, nothing shows a type key), the timer screen reads only the stored draft and the injected clock, the Today cards go through the registry, and M1, L1 and L2 from my 4.3a review are fixed with failing-first evidence. One Medium finding (the two reminder commits that landed after the packet) and three Low findings ride along in 4.3c's Part 0; four Info items follow. Nothing blocks 4.3c.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `08f73d933c22950ee62342146e518eb8fdc1350c`. The packet cites `a09cc1d`, which is two commits back (50fcec1, 08f73d9). See M1 |
| CI | Run 38171144319 (#37) on `a09cc1d`: success, push, 3m20s: api 1m40s, docker-compose 7s, app 3m16s, e2e 1m14s. Run 38187475031 (#38) exists for `08f73d9` (3m38s); the page does not show its result, so I cannot say it passed |
| Test counts | From the packet: Pest 585 (unchanged; no `api/` file in either range, so skipping mutation-check is right), Flutter 596 to 630, e2e 21 scenarios |
| M1 (use mine keeps its place) | `useMine` inserts the new row with the old row's `seq` (free, because `discard` deleted it in the same transaction). The test makes a stale set_value, queues +0.5 behind it, uses mine, and checks the value on screen does not move (3.500 before and after), the send order is set_value then increment, and the server ends at 3.500. A second test checks keep synced with an increment behind it ends at 2.500. A37 carries the sentence. The exception is narrower than it should be: see L1 |
| L1 (rate limit) | `ci.yml` starts the API with `RATE_LIMIT_SYNC_PER_MINUTE=600`; `api-serve.ps1 -E2E` does the same locally. Evidence: the same 21 scenarios took 2m23s in 4.3a and 1m14s here |
| L2 (day-first dates) | `fullDate` ("d MMM y"), `weekdayDate` ("EEEE, d MMMM y") and `dayMonthTime` ("{date}, {time}") live in the ARB and replace the month-first formats in History, the Today header ("Thursday, 28 May 2026", as the design reads), the queue, the reminder editor and the server status. Two deviations in how (see §4) |
| Registry | `hasAmountEntry`, `parseAmount`, `suggestStep`, `progress` (with a spoken form), `plusAmount`, `amountText`, `amountInput`, `amountTitle`, `amountFieldLabel` and `timerClock`. `parseAmount` returns a three-place decimal string for quantity and whole seconds (an integer) for duration, never a double; the test covers the error set. `niceStep` picks 1, 2, 2.5 or 5 times a power of ten nearest an eighth of the target by ratio, ties to the smaller; the test gives 250 ml for 2000 ml, 0.25 for 2, 2.5 for 20, 1 for 8 |
| Screen 34 | Local data only; the day's value and the target in force come from `watchDetail`, so a backdated definition is respected. The stepper and field follow each other, the field keeps the typed text on every error, Add writes one `log.increment` and returns, "Cancel · keep saved value" and Back write nothing, "Time it instead" (duration only) starts the draft and replaces 34 with the timer. Blocked states (gone, archived, one-tap type, unknown type) show words and a way back |
| Screens 33 and 36 | One screen over `watchTimer`. Time = stored draft + injected clock, ticked once a second in this screen only; the spoken value has minute granularity. Finish shows one of: saved, nothing to save, or the refusal in words with the draft kept and "Discard timer" beside it (too long, day cannot hold it, archived). Discard asks first; Back leaves the draft. The 4.3a I1 request (two ways out of a too-long timer) is met by discard plus the hint to add time from Today |
| Today cards (05) | Quantity and duration cards show `1.25 / 2 L` style progress, a "+step" action that opens 34 prefilled and never writes by itself, "· done" with a check once complete, and a timer line that ticks in its own row; the card's own tap still opens 12. Needs-attention and unknown-type rows keep the old branch. Today re-reads when `timer_drafts` changes |
| Screen 12 | A "Add progress" button and, for a type whose rules support a timer, "Start timer" or "Open timer" (a design gap: the design shows no logging controls on 12) |
| Reminders | `replanInBackground` wraps the debounce, app start, resume and account switch; the hide-names switch still awaits and shows the failure. The two later commits: see M1 |
| Docs and gate | A37 has the queue sentence; BUILD_PLAN splits 4.3b and 4.3c; DEVICE_GATE steps 32 to 37 are added with a results row each |

## 3. Findings

**M1 · Medium · Two reminder commits landed after the packet, outside any prompt, with no amendment and no recorded check**
`50fcec1` stops a replan from cancelling a reminder whose time has passed (it may be showing in the tray; cancelling removes it), and `08f73d9` moves reminders to a new high-importance Android channel (`reminders_alert`) so they pop up as well as staying in the tray, deletes the old channel at start, and puts the channel in each reminder's content key so a changed channel replans every pending reminder onto it. They came from the phone session. Neither was in a prompt or in the packet's deviations, and the pasted message said the full check had not run on them. I read both diffs and the code is sound: the fired check uses the scheduler's own clock, the record of a past slot is still dropped, the content-key change replaces rather than duplicates (the test counts schedules doubling while pending stays equal), and by reading, the old code would call `cancel` for the fired slot, so the new test would fail on it (I did not run it). Three things are missing:
1. **A decision on record.** The spec asks for local, neutral reminders and does not say how they are shown; screen 11 is titled "Gentle reminders". A pop-up banner is a product choice (the wording stays neutral and the person can lower the channel in system settings). If it was your call on the phone, record it as A38 (text in the 4.3c prompt). If it was not, tell me and I will write it the other way.
2. **A check.** CI #38 ran for `08f73d9`, but I cannot see its result. 4.3c starts by running `scripts\check.ps1` on the tree as it is and printing the exit code.
3. **Two side effects to write down, not fix.** A reminder that already fired is left alone, also after "Hide habit names" is switched on (the tray keeps the old text until it is cleared) and after the habit is done. The first replan after the upgrade reschedules every pending reminder once.

**L1 · Low · The M1 exception is broader than its reason**
`ASSUMPTION(4.3b-use-mine-after-habit)` says a queued habit change must reach the server first because the restore makes habit_archived resolvable. The code applies it to any later unacked habit row. A person who has a stale set_value waiting, then archives the habit, and then chooses "use mine" gets the new row behind the archive; the server refuses it with habit_archived and the person is asked again, where keeping the place would have sent the value first and the archive after. The fix is a narrower test: only when the row was refused with `habit_archived` and the later habit row is a `habit.restore`. Add to A37: "A use-mine for habit_archived goes after the habit's queued restore; any other use-mine keeps the old row's place." Test: a stale set_value in needs_attention, a queued `habit.archive` behind it, use mine: the new row keeps the old seq, and after sync the server holds the value and the habit is archived.

**L2 · Low · Pause, resume, "Start timer" and "Time it instead" fail silently on an archived habit**
`pauseTimer`, `resumeTimer` and `startTimer` all run `_timerAllowed`, which throws `TimerFailure.archived` when the habit shows archived, and the buttons call them without a catch. A timer running when the habit is archived on another device cannot be paused: the button does nothing (the error goes to the zone), the clock keeps counting, and the only ways out are Finish (refused in words) and Discard. Fix in the writer: pausing only banks time and must work on an archived habit (keep the type check; drop the archived check for pause); resume and start stay refused. Fix in the screens: catch `TimerFailure` on resume, start and "Time it instead" and show the archived words (the failure card on 33 and 36; a snackbar on 12 and 34). Tests: archive while running, then pause works and the time is kept; resume on an archived habit shows the words; no uncaught error.

**L3 · Low · The reminder editor lost its weekday**
`dayMonthTime` has no weekday, and the next-due line on screen 11's editor used to read "Thu, May 28 · 10:15 AM". Reminders are set by weekday (the M T W T F S S row), so the line should keep one. I see no such line in the design (at the size I looked at it), so this is ours: add an ARB pattern with a short weekday, day first ("Thu 28 May, 10:15 AM", the time in the locale's format) and use it there only.

**I1 · Info · Small screen notes (no change required, tell me if you disagree)**
- A 20-page target steps by 2.5 pages. The design shows no "+step" for that card, so it is only a tag-able assumption (`4.3b-step`); a whole-number target could prefer whole steps. Look at it on the phone.
- 12's button says "Add progress" for every type, 34 says "Add time" for duration. Use `type.amountTitle(l10n)` on 12.
- `_Stepper`'s docblock says one adjustable control to a screen reader, but the two `IconButton`s stay in the semantics tree beside it. Check with TalkBack in step 37; both ways in are fine if they read well.
- `_discard` sets its leaving guard before it writes; `_finish` does not, so it relies on its own continuation running before the stream's "draft is gone" branch. In practice that holds (the stream needs another database read and a frame); a guard flag would make it certain.
- While the amount field holds text that does not parse, the button label and the "After saving" card show the last valid amount. Add re-parses the field, so nothing wrong is written.
- `LogFailure` on 34 and 33 is worded as "can't hold that much" for every cause; an archived habit seen only after the screen opened would read oddly. Rare.
- The timer titles "A moment to breathe" and "Pause at your pace" are the design's Meditation copy shown for every duration habit. Leave until the type design drop.

**I2 · Info · `replanInBackground` drops every error without a trace**
`unawaited(replan().catchError((Object _) {}))` is right for an OS refusal, but a real bug in the planner would now also vanish. Print the error in debug builds (`debugPrint`, no tokens or names in it) so the next developer sees it.

**I3 · Info · The debounced `SyncProvider` timer**
`Timer(_debounce, () => sync())` has the same shape. `sync()` has a `finally` and the engine has catch-all handlers (`sync_engine.dart` lines 194, 462 and 731), but I did not trace whether `run` can still throw. 4.3c states in one line whether it can; if it can, the same guard goes in. No other change.

**I4 · Info · For 4.3c's screen 19: a habit edit carries the whole draft**
`updateHabit` sends the whole new state as the payload (4.2b made the form merge per field at save time, so it is current when sent). After a stale refusal, "use mine" sends that old whole draft on `current.version`, so it also puts back this device's old values for fields the person never touched and the other device changed. The screen must therefore list every field where the two versions differ, and say that those fields take the chosen values. That is an honest "mine or theirs", which is what A37 allows.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 M1 exception for a queued habit change | Accepted in a narrower form: see L1 and open question 1 |
| 2 L1 files (`ci.yml`, `api-serve.ps1 -E2E`, `DEV_SETUP.md`) | Accepted; the e2e job time shows it works |
| 3 `replanInBackground`; two profile tests create their habit through the writer | Accepted; see I2 and I3 |
| 4 L2: locale time in `dayMonthTime`; server status shows `fullDate` plus the locale's time; reminder editor drops its weekday | First two accepted (answer 2). The weekday is not accepted: see L3 |
| 5 `TimerDraftView` in its own file; `TodayItem` gains `target` and `timer`; `testApp` takes `initialExtra` | Accepted |
| 6 Registry additions (`amountTitle`, `amountFieldLabel`, spoken progress) | Accepted |
| 7 Spoken timer value at minute granularity | Accepted |
| 8 Explicit token colours for the timer's secondary button | Accepted (the theme's tonal style rendering as a primary fill was a real catch) |
| 9 112 px maximum width for the card's action; "Waiting to sync" on pending amount cards | Accepted |
| 10 One commit holds the "Time it instead" test and the gate steps | Accepted |
| Not in the packet: commits 50fcec1 and 08f73d9 | See M1 |

Design gaps filled (titles per type, a Today "+step" that opens 34, "Time it instead", the action row on 12, "Discard timer" behind a confirm, the too-long wording, "{n} minutes today"): all accepted. XP sentences left out for Phase 5: right.

## 5. Open questions (answered)

1. **Accept the M1 exception for a queued habit change?** Yes, narrowed (L1). A37 gets a matching clause.
2. **Queue date-time: 24-hour or the locale's?** The locale's, as built. The prompt's "10:15" was an example. Screen 19 uses the same rule.
3. **Does the reminder editor's next-due line keep a weekday?** Yes (L3).
4. **Deviation 3's note on the `SyncProvider` timer:** see I3.

## 6. Risks to keep in view

- **Real-device behaviour is still unproven.** The device gate (steps 1 to 14, 16 to 26, 27 to 37) has not been run. Steps 32 to 37 are new; step 34 (a locked phone keeps counting) and step 35 (kill the app while a timer runs) are the ones only a phone can answer.
- **The head is not yet shown green.** CI #38 ran for `08f73d9`; confirm its mark on the Actions page or take it from 4.3c's first check.
- **A forgotten timer** (running more than 25 hours) cannot be saved and has to be discarded. Your call whether it should pause itself after a long time; I have not asked Claude Code to build anything for it.
- **Timers count wall time** (a changed clock adds time; a timer started at 23:40 and finished at 00:20 files all 40 minutes under the new day), as A36 says.
- **Needs-attention rows still reach people only through the queue (18)** until screen 19 exists (4.3c).
- **The PHP dev server on port 8001 and the dev test account** are on the build machine; keep the account out of every commit.
- **My 4.1 review still carries one wrong sentence** (the engine lines 370 to 371 were inside the bootstrap transaction); the 4.2a review has the correction.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Tell me whether the pop-up reminder channel was your decision (M1).
4. The legal items are still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
5. Phase 4.3c (the prompt follows in the reply): Part 0 for M1, L1 to L3 and I1 to I3; the conflict review (19) with its variants; the queue wording and the links to 19; device-gate steps for reminders and conflicts; the Phase 4 gate mapping and close.
