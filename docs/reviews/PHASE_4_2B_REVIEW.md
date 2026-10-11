# Phase 4.2b review (type-widget registry; screens 10, 08, 09, 22; Edit on 12; the archived link on 07)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-11
Scope: `7cae4c2..927d6cc` (13 commits, 44 files; nothing under `api/` or `contract-fixtures/`). Read at code level: the diffs of `local_mutation_service.dart`, `habit_draft.dart`, `habit_actions.dart`, `local_view.dart`, `router.dart`, `habit_detail_screen.dart`, `habit_library_screen.dart`, `habit_format.dart`, `habit_ui.dart`, `architecture_test.dart`, `sync_e2e.dart`, `DEVICE_GATE.md` and the ARB additions; in full: `habit_type_ui.dart`, `frequency_choice.dart`, `frequency_screen.dart`, `create_habit_screen.dart`, `edit_habit_screen.dart`, `archived_habits_screen.dart`, `habit_form.dart`; the L1 test and the first five tests of the 09 widget suite; the test names of every new suite. I did not read the bodies of the other new tests, the generated l10n files or the rest of `sync_e2e.dart`. I did not run any check, did not open the per-job CI results, and did not see the four screenshots (they stayed on Claude Code's machine).

## 1. Verdict

**Phase 4.2b is accepted.** The registry is the only UI code that knows the types and a test now proves it; screens 10, 08, 09 and 22 exist in full, validate through the same `HabitDraft` the server rules were copied into, write nothing on a refused or unchanged form, keep what the person typed, and sit behind real routes. The five Part 0 fixes were each made failing-first. The first non-daily schedules the app has ever sent go through a real server in the new e2e scenario and come back identical. Two Low findings (a stale copy saved from 09, and a getter that throws in a build) and one Low about date order go into 4.3's Part 0; five Info items follow. Nothing blocks 4.3.

## 2. What I verified

| Check | Result |
|---|---|
| `927d6cc` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `927d6cc322a9b2ce38f104ef48c730368bf0736d`. The packet said "not pushed" (no DNS on Claude Code's machine); Khay Studios pushed it by hand |
| CI run 38150250729 | Success on `927d6cc`, push, 3m31s: api 1m34s, docker-compose 5s, app 3m27s, e2e 1m26s. The run page shows only the overall result |
| Test counts | Pest 585 (580 passed, 5 skipped; unchanged, and the diff touches no `api/` file, so skipping mutation-check is right), Flutter 498 to 551, e2e 16 to 17 scenarios. From the packet |
| L1 | `updateHabit` folds into the unsent create only when it is the newest unacked row; otherwise it rewrites the newest pending `habit.update` (same mutation id and base version) or appends. The test builds the exact sequence (create in flight, edit, failed send, edit again), checks the outbox shape and that the server ends with the second edit |
| L2 | `HabitEditFailure.archived`, thrown first, before any write; tests for a confirmed archive and for a queued archive undone by a later restore |
| L3 | Labels for all five categories; the 09 chooser always lists the habit's own value; two widget tests |
| I1 | `isCalendarDate` parses and formats back ("2026-02-31" is refused); name and unit count runes; `createHabit(draft, type:, reminder:)` validates before it writes and throws `invalid` with the problems; `createOneTapHabit` is a thin wrapper; the three named tests pass unchanged. The old method became `createHabitUnchecked` for tests and tools |
| I2 | `inForceToday` no longer guesses; `toggle` writes `targetOn(date)`. See L2 for how it fails |
| Registry | `HabitTypeUiRegistry` with yes/no, quantity and duration, each with `initial`, `parse`, `format` and `buildTarget`. Quantity goes through thousandths to `"250.000"` and never a double; duration goes minutes to whole seconds and the round trip holds for every whole second (the rounding error is under 0.03 s). `UnknownTypeCard` for any other type. The guard allows type keys only in the provisional rules and the registry, and a self-test shows it catches a planted literal |
| Screen 10 | Four options, selection by symbol plus words, ISO weekdays sent sorted, steppers 1 to 7 and 1 to 365, start date picker, the week card only for times-per-week, the freeze sentence left out. An unknown schedule goes back unchanged (A21) |
| Screen 08 | Replaced in full; one calm message per field, the first focused, typed text kept across a failed submit and a type switch; habit and reminder in one transaction through `createHabit` |
| Screen 09 | Starts from the latest definition (`HabitView.editable`, now null when blocked, with `editBlocked` saying why); "Waiting to sync" only for definition edits, "New target starts {date}" only from `pendingFrom`; an unchanged save writes nothing; archive behind a confirm sheet and then back to the library |
| 12, 07, 22 | Edit button (44 px) only when editable, the reason in words otherwise; "N archived" is a 44 px link and a router test proves `/habits/new` and `/habits/archived` match before `/habits/:id`; 22 shows the two cards even when empty and "Archived" without a date for an unsent archive |
| e2e `habit-schedules` | Five habits created offline through the validated draft (daily, weekdays `[5,1,3]`, 3 a week, every 2 days, 30 minutes as 1800), every ack accepted, the canonical config B pulls equals A's, weekdays come back `[1,3,5]` |
| Copy | No new string threatens loss; the one design string that trips the guard is exempted by its exact text in the guard, and the 09 test pins that same string |

## 3. Findings

**L1 · Low · Screen 09 can save a stale copy and revert another device's edit**
The form is filled once, from the first view of the habit. `updateHabit` compares the draft with what the habit shows now and, when they differ, queues the whole state with the newest known version as its base. So if a pull brings a change from another device while 09 is open, pressing Save queues the old values on top of the new version. No conflict is raised, because the base version is current. This holds even when the person changed nothing: the form differs from the pulled habit, so a plain Save writes a revert.
Fix: remember the start draft; at save, build the draft field by field. Where the form still equals the start value, take the habit's current value; where the person changed it, use theirs. A pure function in `habit_draft.dart` (for example `HabitDraft.merged(start, current, edited)`) keeps it testable. Tests: open 09, pull a rename, change only the target, save: the payload carries the new name and the new target. Open 09, pull a rename, save untouched: nothing is written.

**L2 · Low · `inForceToday` throws inside a build**
The library row reads it while building. `HabitView.today` is null when the account calendar is not known, so the getter throws a `StateError` and the screen turns into the error widget. The first-run setup screen writes the calendar before the library can open, which keeps this rare, but a throw in a build is a loaded gun. The library row already falls back to the habit's own values when the getter is null (`inForce?.wire[...] ?? p[...]`), so returning null is the graceful form of "no guess".
Fix: return null without a clock; update the test that pins the throw; make the library tolerate null as it already does.

**L3 · Low · Dates read month-first where the design reads day-first**
`HabitFormat.dayMonth` and `ScheduleText.date` use `DateFormat.MMMd`, which prints "May 29". The design prints "29 May" ("Archived 12 May", and the code's own comments say "27 May"). The app has one locale, `en`, so every English device reads month-first, including Ghana's. Screen 22 alone uses the fixed `d MMM` I put in the prompt, so one flow now shows both orders: 09 says "New target starts May 29" and 22 says "Archived 12 May". The design wins on how a screen reads, so day-first is right.
Fix: one pattern for `dayMonth` and `ScheduleText.date`, `d MMM` held in the ARB (the same string 22 uses), so 07, 09, 10, 12, 13 and 22 agree. Update the tests that expect "May 29". Fix the stale "27 May" docblock only if it is still wrong afterwards.

**I1 · Info · Two traps on screen 10**
(a) The start-date range is computed from the live anchor, not the one the screen opened with. After the first pick, the earlier anchor can no longer be chosen again, and an existing anchor later than today + 365 (set by another client) puts the picker's initial date outside its range. Compute `first = min(original, today)` and `last = max(original, today + 365)` once, in `initState`. (b) `state.extra! as FrequencyRequest` throws when the route opens without its extra (a restored or deep-linked `/frequency`). Pop to the previous screen, or go to Today, instead.

**I2 · Info · A refused create or edit shows its first problem under the name**
In the `catch` after the write, `HabitFormErrors(name: first problem)` puts the message under the name field whatever the field. The same rules ran first and a refusal here is unreachable today, so no one sees it; route the catch through `validateHabitForm` or map the problem to its field.

**I3 · Info · The weekday row wraps by accident**
Seven 44 px toggles with gaps need about 330 px; inside the summary card's padding a 360 to 411 dp phone has about 264 to 315. Sunday wraps (the packet's own risk). It is usable, but a lone Sunday on a second line looks like a bug. Make it deliberate: for example 4 + 3 in a grid, or let the toggles use the card's full width. Look at it at 360 dp and at 200% text.

**I4 · Info · Small things**
The Edit button on 12 reads only "Edit" to a screen reader; "Edit {habit}" (as the setting rows do). `reminder_screens_test` now taps `find.text('Edit').last`, which depends on order; a key is sturdier. The untagged choices the packet lists (yes/no as the default type on 08, the unknown-type card copy, the summary and blocked-note wording) should carry `ASSUMPTION(4.2b-...)` tags so the next phase can find them. 09 loads the whole habit detail (heatmap and progress) just to fill a form; fine now, worth a lighter query later.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 PyMuPDF instead of pdftoppm for the design crops | Accepted (tooling on the machine, not in the repo) |
| 2 Old `createHabit` renamed `createHabitUnchecked` | Accepted; the e2e still uses it for setup and the validated one for the new scenario |
| 3 `HabitView.editable` nullable, new `editBlocked` | Accepted; the shape reads well on 09 and 12 |
| 4 The loss-wording guard exempts the design's 09 subtitle | Accepted (see answers) |
| 5 4.2a regression: 07 always showed "0 archived" | Accepted, and my miss: `watchHabits` stopped returning archived habits in 4.2a, the library counted from that list, and my 4.2a review passed the library diff without seeing it. Claude Code's new link test found it |
| 6 `reminder_screens_test` taps `.last` | Accepted; see I4 |
| 7 `InfoCard.body` optional, `ScreenHeader.subtitleWidget`, `FieldErrorText`, `CountStepper`; `detail()` passes the clock | Accepted |
| 8 Screen 22 uses the fixed `d MMM`, 09 the locale's own format | Accepted as built; L3 makes both the same |

## 5. Open questions (answered)

1. **Keep the guard exemption or reword the 09 subtitle?** Keep the exemption. The subtitle is the design's own copy and reads as reassurance, not a loss threat. The exemption is one exact string and any other wording with those words still fails; leave it exactly that narrow.
2. **22's date: fixed `d MMM` or the locale's format?** Neither as they stand: L3 makes one `d MMM` pattern from the ARB the app's day-month format everywhere, 22 included.

## 6. Risks to keep in view

- **I have not seen the screenshots.** The one to look at is 10 with the weekdays chosen (I3).
- **Real-device behaviour is unproven.** The device gate (steps 1 to 14, 16 to 26, and the new 27 to 31) has not been run. 27, 28 and 31 are the ones this phase put at risk.
- **Two fragile tests are on record**: the profile widget tests that can hang under heavy parallel load, and the reminder test that failed on one extra query. If either shows in CI, fix the test's wait, not the product.
- **The first non-daily schedules are out.** The e2e proves create and pull; it does not prove due-ness on a device (gate step 30) or reminders for a weekdays or interval habit (step 29).
- **Needs-attention goes to the sync queue (18), not to a review screen.** The queue lets the person discard a stale habit edit; the choice between the two values (19) comes in 4.3.
- **Housekeeping on Claude Code's machine:** the PHP dev server on port 8001 is still running.
- **My 4.1 review still carries one wrong sentence** (the engine lines 370 to 371 were inside the bootstrap transaction); the 4.2a review has the correction.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone: steps 1 to 14, 16 to 26 and 27 to 31.
2. Put this file in `docs/reviews/`; the 4.3 prompt tells Claude Code to commit it unchanged as its first commit.
3. The legal items are still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. Phase 4.3 (the prompt follows in the reply): L1, L2, L3 and I1 to I4 in its Part 0, then logging.
