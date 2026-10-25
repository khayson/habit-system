# Phase 6.7 review (the app's toast, Hugeicons, and the 6.6 fixes)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-25
Scope: `6245a34..727086f` (9 commits, 62 files, +1,088 / −235). Read at code level: A52; the shape of `app_toast.dart` (its static current entry, timing and dismissal); how `HabitFormat.icon` picks a habit's icon; the session provider's sign-out paths. Read by the packet and commit list only: the L1 and I1 fixes and their tests, the eight replacements, the icon registry, the theme and test changes. I did not see the screenshots and did not run any suite.

## 1. Verdict

**Phase 6.7 is accepted.** Snackbars are gone and an architecture test keeps them out; every icon comes through one Hugeicons registry (hugeicons 1.2.0, MIT, as the packet found); the 6.6 findings are fixed with failing tests first. One Low finding about the toast, and one product gap Khay Studios found: a habit's icon shows its type, not what the habit is.

**On the toast.** My 6.7 prompt read "no snackbar" as "no floating message at all" and asked for inline messages. Khay Studios told Claude Code it wanted a modern floating toast instead, and A52 records that. A52 stands; the inline-message parts of my prompt are withdrawn.

**CI:** the packet reports run 40230404270 with all four jobs green. I could not open the run page from my side; the head SHA I verified.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `727086f5a644c513ae5ef93037bf1ff949f5978d`. 9 commits; the first is `ded13bb`, and `PHASE_6_6_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| Test counts | From the packet: Pest 742 (737 passed, 5 skipped), Flutter 875 (was 862), mutation check 76 of 76 |
| A52 | Records Khay Studios' toast decision and the icon registry: one toast at a time, about 4 s (6 s with an action), a close button and swipe up, kept while a screen reader is on, polite live region, no slide under reduced motion; sign-in notices stay as cards; `Icons.` and direct `HugeIcon` use outside the registry fail a test |
| Toast code | A single static `_current` overlay entry; a new toast dismisses the old one; a timer dismisses it unless a screen reader is on |
| Habit icons | `HabitFormat.icon(rules)` switches on the habit's type display: every yes/no habit shares one icon, every quantity habit shares one (the water drop), every duration habit shares one. Seven call sites use it |

## 3. Findings

**L1 · Low · A toast outlives the account it belongs to**
The packet's risk. The toast sits on the root overlay with a static current entry, so it stays up across sign-out or an account switch. An Undo toast holds an action bound to the old account's writer: tapping it after signing out acts on a closed account, or fails. Fix: dismiss the current toast on sign-out, on a 401 sign-out, on account deletion and on an account switch; and an action whose account is no longer the active one does nothing. A failing widget test first.

**I1 · Info · Unformatted files reached a commit**
The icon commit left three files unformatted and `727086f` fixed them. History is still clean of generated files, and the check caught it before the push. Format files by name before each commit, as the working rules say.

## 4. Product gap found by Khay Studios: a habit's icon shows its type

A "Reading" habit counted in pages is a quantity habit, so it shows the water drop; "Pilates" and "Meditation" share the timer icon. The design draws an icon that fits each habit (a book for reading, a drop for water, a clock-like mark for meditation). Next phase: each habit gets its own icon, chosen by the person from a small set, with a suggestion from its name and a default from its category. The type icon stays where the type itself is shown (the type switch on create).

## 5. Deviations

| # | Verdict |
|---|---|
| Toast instead of inline messages | Accepted: Khay Studios' decision (A52) |
| No new "Saved" wording after an edit | Accepted. The packet's question is answered below |
| Reminders soft-deleted with their habit | Accepted; it lets I1 answer `resource_deleted` |
| `byAppIcon` helper, `strokeRounded*` names, Material's internal glyphs out of scope, `toastClose` | Accepted |
| No new ASSUMPTION tags | Noted |

## 6. Open questions (answered)

1. **A "Saved" toast after a habit edit.** Yes, short and calm: "Changes saved." The edit screen closes back to the habit, so the toast is the only sign it worked. It is the same wording family as History's toast, so no design drop is needed.

## 7. Cloudflare R2 (for the deployment phase)

The `habit-files` bucket exists in Western Europe, which suits the Frankfurt choice for Render and Neon. Two settings must change before any photo or export goes in:
- **Public access is on, and the public development URL (`pub-…r2.dev`) is enabled. Turn both off** (bucket Settings, Public Development URL, Disable). Photos and exports are private; the API streams them to their owner only (A20, A48), so the bucket never needs to be public.
- **Create an API token** under "Manage API Tokens" with Object Read and Write on `habit-files` only. Keep the Access Key ID and Secret out of the chat and out of the repository; they go into Render's environment settings in the deployment phase.

The other bucket on the account (`schoolbookapp`) is not part of this project; check its public access too.

## 8. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 103 of `docs/DEVICE_GATE.md`.**
- **I could not verify CI for 6.2 to 6.7.**
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.

## 9. Next steps

1. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
2. Turn off R2 public access and create the scoped API token (section 7).
3. **Phase 6.8: a chosen icon for each habit, the "Changes saved." toast and L1.** The prompt follows in the reply. The deployment phase comes after it.
4. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone.
