# Phase 5.3b review (`xp_earned` from the ledger, screens 14 and 15, the Insights tab)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-23
Scope: `0ec75cb..ce742b3` (10 commits, 19 files, +1,959 / −115). Read at code level: the `InsightsQuery` and `ConsistencyCalculator` diffs, the new mutant, the domain test change; `insights_screen.dart` in full; the router and shell diffs; the ARB additions; the `SPEC_AMENDMENTS`, `BUILD_PLAN` and `DEVICE_GATE` diffs. The rewritten fixture I compared by parsed content against `0ec75cb`, not by text diff. Read by name only: `insights_screen_test.dart` (10 `testWidgets`, the last one run for both periods, so 11 cases), the e2e scenario. Not read: the generated l10n files. I compared the strings with design screens 14 and 15. I did not see the three screenshots and did not run any suite.

## 1. Verdict

**Phase 5.3b is accepted, and with it Phase 5 is built.** `xp_earned` is now the XP the person was given, through yesterday, and the screens show what the server sent with every state the prompt listed. Two Low findings and three Info notes. Phase 5 now waits only on the device gate.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `ce742b3af326c1c316a071e51ad67d1eeac5c3e5`. 10 commits; the first is `c420785`, and `PHASE_5_3A_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Run 39597154736 on `ce742b3`: success, push, 4m12s: api 2m01s, docker-compose 7s, app 4m07s, e2e 1m14s. The page shows only the overall result and the job times |
| Test counts | From the packet: Pest 661 to 662 (the today case), Flutter 772 to 784 (11 screen cases and one more), mutation check 52 of 52. The new mutant moves the upper bound to today and names the endpoint test |
| `xp_earned` | Active `xp_entitlements` for the user with `log_date` from `start` to yesterday, × `XpRules::XP_PER_COMPLETION`; 0 when `through` is null. With a category, each row's habit schedule is loaded once and the definition in force on that date decides. `earnedXp` and its domain assertion are gone; the domain fixture keeps a note pointing at the endpoint fixture |
| Fixture rewrite | Parsed old against new: the only changes are the week case (renamed, `xp_earned` 90 to 120, a new "Weekend walk" habit due on Saturdays only with a check-in on Tuesday 26 May, and an `xp_note`), the archived case (renamed, 30 to 60), the new "today's completion is not counted" case, and the description. The packet's "data unchanged except the edits" holds |
| A47 | The `xp_earned` sentence is replaced, not appended to, and matches the code |
| Tab and route | `/insights` inside the shell; the Insights tab is selected there and Today is not; the disabled state is gone |
| Screen | Shows the session's last answer for the period at once, then fetches; pull to refresh; the Week/Month choice is held for the session. Offline (network or timeout) with no answer: the calm line; with an answer: the answer and "These are the last numbers from this session."; other errors with no answer: the neutral line and Try again at 44 px. The unsynced line watches the queue for unacknowledged `habit_log` rows |
| Week (14) | Null percent shows "No closed periods yet"; null `through` shows "No closed days yet". Bars use `barFraction`, future and zero days draw a flat line, each day has its own label (Today "so far", future "not yet"). Open weekly rows use local names or "A habit", with "Pending" as a word. The note card is word for word |
| Month (15) | The big card, the category rows in the order sent with one label each (name, counts, percent), the bar as display arithmetic, the footer word for word. Unknown categories go through `HabitFormat.category`, which the test pins as "Other" |
| No client rules | The screen computes nothing beyond bar widths and date formats; it never writes to the database |
| e2e | `insights`: a synced backdated completion adds one completed period and 10 XP; a not-due check-in adds 10 XP and leaves the totals alone. 25 scenarios in the packet |
| Legal | Nothing new is collected; "no change" holds |

## 3. Findings

**L1 · Low · The numbers stay old after the waiting check-ins sync**
While the screen is open, the "Check-ins waiting to sync aren't counted yet." line disappears as soon as the outbox drains, but the numbers are the ones fetched before. That reads as "they are counted now" when they are not. Fix: when the count of unacknowledged `habit_log` rows drops from above zero to zero while the screen is shown, fetch once more for the current period. A failing widget test first: the line shows, the rows are acknowledged, the service is called again and the new numbers show.

**L2 · Low · A failed refresh is silent when an answer is already shown**
`_failed` only renders when nothing is shown, so a pull to refresh that hits a server error keeps the old numbers with no sign that they were not refreshed. Show a quiet line, "Couldn't refresh right now.", with Try again (44 px), the same way the offline line works. One widget test.

**I1 · Info · "+0 XP" on a Monday**
With nothing closed yet the tile reads "+0 XP" over "No closed days yet". It is true and not a loss message. Accepted.

**I2 · Info · One Today test failed once under load**
"New · waiting to sync" was not found in one full run that took 3:14 instead of about 1:15, and passed on rerun and three times alone. Not chased now. If it fails again, record the test name and the run time in the packet, and treat a second failure as a bug to fix at its cause.

**I3 · Info · The Back arrow on a tab root**
Design 14 and 15 draw it; it goes to Today, as Profile's does. Accepted (deviation 2).

## 4. Deviations

| # | Verdict |
|---|---|
| 1 No null-through screenshot and no Week at 2.0 screenshot | Accepted; both are widget tests, and gate steps 67 and 71 cover them on a phone |
| 2 Back arrow to Today | Accepted (I3) |
| 3 The tiles stack above text scale 1.5 | Accepted |
| 4 "+0 XP" when nothing is earned | Accepted (I1) |
| 5 Screen and tab commits reordered before the push | Accepted; nothing was pushed in between |
| 6 The JSON writer rewrote the fixture | Accepted; checked by parsed content (section 2) |
| 7 No new ASSUMPTION tags | Noted |
| 8 `docs/legal`: no change | Accepted |
| 9 Local only: dev API and PostgreSQL restarted, migrations applied, 7 backdated check-ins on the screenshot account | Accepted. None of it is in a commit |

## 5. Open questions (answered)

1. **The screenshot account's old unsent row.** No action. It is a dev leftover that shows the line correctly. If you want a clean account for later screenshots, discard that change from the sync queue screen.

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 71 of `docs/DEVICE_GATE.md`.** Phase 5 is complete in code, so the whole of Phase 5 (steps 46 to 71) can now be run in one pass.
- **Insights is a network action.** A first open offline shows only the calm line, by design.
- **A timezone change can move the freeze watermark backwards** (from 5.1). No test.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **My 4.1 review still carries one wrong sentence**; the 4.2a review has the correction.
- **Dependabot has open branches.** Check CI and the generated diff before any merge.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone, steps 46 to 71 for Phase 5.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Legal items, still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. **Phase 6 (account and portability) is split** so each review stays readable: **6.1** exports (screens 21, 29 and 30), **6.2** account deletion (28), **6.3** imports (31 and 32), **6.4** password reset (25 to 27, needs a domain and an email provider, A15), **6.5** milestone push (needs a Firebase project). 6.4 and 6.5 wait on your two decisions; 6.1 to 6.3 need none. The 6.1 prompt follows in the reply.
