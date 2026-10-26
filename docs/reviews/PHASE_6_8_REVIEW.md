# Phase 6.8 review (a chosen icon for each habit)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-26
Scope: `727086f..f7bcdea` (12 commits, 56 files, +14,493 / −64; most of the additions are the generated icon catalog). Read at code level: the `habits.icon` migration and its call into the backfill. Read by the packet and by name only: A53, the fixtures, the server validation and presenter, the backfill, the app catalog, the picker, the screen changes, the toast fix and every test. I did not see the screenshots and did not run any suite.

## 1. Verdict

**Phase 6.8 is accepted.** Each habit now shows its own icon, chosen from the full free Hugeicons set (Khay Studios widened the 40-icon catalog, A53), suggested from the name and defaulting to the category's icon. The icon is presentation only and never touches periods, XP or streaks. The 6.7 toast finding is fixed. Two Low findings and two Info notes; none blocks deployment.

**CI:** the packet reports run 40242492870 with all four jobs green. I could not open the run page; the head SHA I verified.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `f7bcdea56b08fe6d7cbca825841f14d4dad22a9c`. 12 commits; `PHASE_6_7_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| Test counts | From the packet: Pest 766 (761 passed, 5 skipped), Flutter 901 (was 875), mutation check 79 of 79 (three new) |
| Migration | `habits.icon varchar(64)` null with a CHECK on a lower-case, hyphenated key shape; the rollback drops both; the migration then runs `HabitIconBackfill` |
| R2 | Khay Studios' screen shows the `habit-files` bucket with **Public Access: Disabled**. Good |

## 3. Findings

**L1 · Low · Conflict review cannot show an icon-only difference**
The packet's second question. Screen 19 lists the fields that differ; when only the icon differs it shows nothing, and the person cannot tell what they are choosing between. Add an "Icon" row (the two icons with their labels) to the habit conflict view. A widget test.

**L2 · Low · No way back to the category's icon**
The packet's third question. Once an icon is picked, the person cannot return to the default. Add "Use the category's icon" at the top of the picker; it sends `icon: null`. A widget test.

**I1 · Info · A migration that calls application code**
The icon migration runs `HabitIconBackfill`, an application class. If that class changes later, a fresh database still migrates (it has no habits), but an old database migrating late would run today's code, not the code of 6.8. Acceptable now that production does not exist yet; from the first deployment on, keep data changes inside the migration file itself.

**I2 · Info · The full icon set adds 4.4 MB**
The arm64 APK grows to about 30.9 MB. That is acceptable for v1; the picker needs the whole set to search it.

## 4. Deviations

| # | Verdict |
|---|---|
| The whole icon set with search (A53) | Accepted: Khay Studios' decision |
| The server checks the key's shape only, `varchar(64)` | Accepted; a newer app's key syncs to an older server |
| The backfill bumps the version and journals | Accepted, and needed |
| No habit icon on 12, 17, timer and amount | Accepted (design) |
| `icon` through the existing `extra` field, no drift migration | Accepted. The tolerant `extra` path already carries unknown fields |
| "Heart health" label; Icon row positions; three tests updated | Accepted |
| No new ASSUMPTION tags | Noted |

## 5. Open questions (answered)

1. **English-only icon names and search.** Fine for v1; the app is English-only.
2. **Icon in conflict review.** Yes (L1).
3. **"Use the category's icon".** Yes (L2).

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 110 of `docs/DEVICE_GATE.md`.** Run it next, on the deployed server with the release APK.
- **I could not verify CI for 6.2 to 6.8.**
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.

## 7. Next steps

1. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
2. **Phase 7a: the first deployment** (Render and Neon in Frankfurt, Cloudflare R2, Brevo, a signed APK and a download page), with L1 and L2. The prompt follows in the reply. Claude Code prepares everything in the repository and writes a step-by-step runbook; Khay Studios clicks through the dashboards and holds every secret.
