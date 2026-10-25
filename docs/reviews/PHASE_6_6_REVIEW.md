# Phase 6.6 review (deleting a habit, and swipe to archive or delete)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-25
Scope: `2bfab04..6245a34` (19 commits, 50 files, +2,070 / −106). Read at code level: `HabitWrites::delete` and the shared owner and version checks, the `habits.deleted_at` migration, `LocalMutationService.deleteHabit`, and the list of every `SnackBar` in the app. Read by the packet and by name only: the reset-failure ceiling, the readers that skip deleted habits, the swipe widget, the bottom sheet, the conflict and queue changes, the tests, A51. I did not see the screenshots and did not run any suite.

## 1. Verdict

**Phase 6.6 is accepted.** A delete is one journaled mutation that removes the habit's content on every device and keeps the XP and freeze ledgers whole; the deleting device drops only the rows that could never apply. One Low finding, and two decisions by Khay Studios on 2026-10-25 that reshape part of what was built: **no snackbars anywhere in the app**, and **Hugeicons for every icon**. Both go into the next phase with the findings.

**CI:** the packet reports run 40220882125 with all four jobs green. I could not open the run page from my side (third time); the head SHA I verified.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `6245a34d625422e6f59d030c46174d1ab24225e7`. 19 commits; the first is `8dbf8fb`, and `PHASE_6_4_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| Test counts | From the packet: Pest 741 (736 passed, 5 skipped), Flutter 862 (was 845), mutation check 76 of 76 (six new) |
| Server delete | Owner-scoped and locked; an already deleted habit is acknowledged with no change; otherwise version-checked, then each live log and reminder is journaled as a delete before the rows go; logs, reminders, evaluations, streak cache, ranges and definitions are removed; the habit becomes a tombstone (empty name, no unit, new version) journaled as a delete. Update, archive and restore on a deleted habit answer `resource_deleted` |
| Schema | `habits.deleted_at`, an index on (user_id, deleted_at), and a CHECK that a deleted habit's name is empty; the rollback drops all three |
| App delete | One drift transaction: the habit's unacknowledged rows that are not in flight are dropped; `habit.delete` is queued on the newest version seen (confirmed, or a newer acknowledged one), unless the habit never left the device; the habit, its logs, drafts and reminders are removed locally |
| Snackbars | Eight places use one: the swipe's archive and restore Undo and the "Deleted" line, the timer's archived message (twice), the edit save, the history save, the conflict review result, and the profile sheets |

## 3. Findings

**L1 · Low · A stale delete becomes a conflict for a habit the person can no longer see**
If the habit changed elsewhere (an edit or an archive synced from another phone), the deleting device's `habit.delete` carries an old `base_version` and comes back 409. The habit is already gone from this device, so the person would be asked to review a change to something they deleted. A delete's intent cannot be misread. Fix: treat `habit.delete` like A45's desired states: on `version_conflict`, rebase once on the server's version and send again; only a second conflict needs attention. Add it to `_rebasesOnce` and to A51. A failing test first.

**I1 · Info · A reminder edit for a deleted habit comes back `not_found`**
The packet's first question. Yes: when the reminder's habit is deleted on the server, answer the same `resource_deleted` as log writes, so the queue shows "This habit was deleted on another device." Small, with the next phase.

**I2 · Info · Older app versions and the tombstone**
The packet's second question. No released version exists yet, so nothing old is in anyone's hands. Before the first public build, Phase 7 adds a minimum supported version check (the server answers a header or an endpoint, the app asks the person to update). Nothing now.

**I3 · Info · One transaction for a long history**
The packet's risk, the same shape as the account purge. Phase 7's load test covers both.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 `password_reset_failures` table | Accepted; it joins the purge |
| 2 Undo queues `habit.restore` | Accepted; the next phase replaces the snackbar that carries it |
| 3 Unsent `habit.update` and reminder rows dropped too | Accepted, and right |
| 4 A habit that never synced sends no delete | Accepted |
| 5 Rejections under a deleted habit keep the row's own id | Accepted |
| 6 Server logs hard-deleted with the habit | Accepted; the journal carries the deletes to other devices |
| 7 The confirmation is a bottom sheet | Accepted |
| 8 `snackBarTheme.actionTextColor` | Superseded: snackbars leave the app (next phase) |
| 9 `DestructiveButton` shared | Accepted |
| 10 The tombstone test syncs with the screen unmounted | Accepted |
| 11 No new ASSUMPTION tags | Noted |
| 12 Local only: dev DB migrated, Water archived and restored on the emulator | Accepted |

## 5. Open questions (answered)

1. **Reminder rejections should name the habit.** Yes (I1).
2. **Older versions.** Not needed now; a minimum-version check comes in Phase 7 (I2).

## 6. Decisions by Khay Studios (2026-10-25)

- **No snackbars, toasts or floating messages in the app.** Every message appears inside the screen it belongs to, near what caused it.
- **Icons come from Hugeicons** (the free stroke-rounded set on pub.dev), through one icon registry, replacing Material icons everywhere in the app's own UI.

## 7. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 97 of `docs/DEVICE_GATE.md`.**
- **I could not verify CI for 6.2, 6.4 or 6.6.** Please open those runs once in a browser.
- **Storage for photos and exports is still undecided** (Cloudflare R2 or the Neon fallback); the deployment phase waits on it.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.

## 8. Next steps

1. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
2. **Phase 6.7: no snackbars, Hugeicons, and L1.** The prompt follows in the reply.
3. **Tell me what happens when you create the `habit-files` bucket in R2.**
4. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone.
