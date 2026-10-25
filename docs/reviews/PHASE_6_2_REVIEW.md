# Phase 6.2 review (account deletion, with the 6.1 fixes)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-25
Scope: `0ff6f94..1ebed79` (19 commits, 62 files, +2,667 / −37). Read at code level: `AccountDeletionService`, `AccountPurger`, `AccountController`, `OpenExports`, the `ChangeJournal`, `MutationApplier`, `AuthController` and `HealthController` diffs, the `account_deletions` migration, the route and scheduler diffs, and the no-habit-delete sentence in `SPEC_AMENDMENTS.md`. Read by name and by the packet only: the Pest, concurrency, Dart, widget and e2e tests, the app's deletion code, the fixtures, A49, the 6.1 fixes on the app side. I did not see the screenshots and did not run any suite.

## 1. Verdict

**Phase 6.2 is accepted.** Deleting an account needs the password, ends every session in the same transaction that marks the account deleted, and hands back a receipt that can read one status and nothing else. Every writer takes the user lock, and the lock now refuses a deleted account, so a request racing the deletion either commits first (and is purged) or gets 401. The purge removes owned rows from a list that a test checks against the schema. All five 6.1 findings are fixed with failing tests first. One Low finding and three Info notes.

**One check I could not make this time.** The GitHub run page for 40180672626 was not reachable from my side (the address was refused, and the Actions list I could reach is an old cached page). The CI result in this review is the packet's word, not mine. The head SHA I did verify.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `1ebed79876d4385dc113b36b8d3d845fdaf7520c`. 19 commits; the first is `c607435`, and `PHASE_6_1_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Not verified by me (see above). The packet reports run 40180672626 passing all four jobs |
| Test counts | From the packet: Pest 715 (710 passed, 5 skipped), Flutter 832 (was 812), mutation check 63 of 63 (six new) |
| M1 (6.1) | `OpenExports` defines live and stale jobs (running and silent 30 min, queued 24 h); POST looks only at live jobs; the sweep fails stale ones; `failed()` on the job marks it failed and deletes the object |
| L1 to L4 (6.1) | From the packet and the route diff: `/privacy` inside the shell; download sent only to the configured base; the health check returns 503 outside local and testing for the test key or a short one, warns on a missing one; the 410 message |
| DELETE /me | `auth:sanctum` and its own throttle; the password checked with `Hash::check`; then one transaction: user lock, `deleted_at`, every Sanctum token of the user deleted, the deletion row with the receipt's SHA-256 and a 35-day expiry, the purge job dispatched after commit |
| Receipt | `GET /account-deletions/{id}` sits outside `auth:sanctum`; a missing or wrong receipt, an expired one, a non-UUID id or another deletion's id are all the same 404; `hash_equals` on the hash; the answer holds id, status and two times only |
| Lock | `lockUser` throws `AccountDeleted` (401) when the user is missing or deleted once the lock is held; the applier rethrows it rather than turning it into a per-mutation error |
| Login | A deleted account is looked up as an unknown email, so the answer and the bcrypt work match a wrong password |
| Purge | Objects first by owner prefix, then one transaction under the lock deleting 17 tables in dependency order, marking the deletion completed with `user_id` null, and deleting the user row. A completed or missing deletion is skipped, so a second run does nothing. `accounts:purge` every 5 minutes picks queued and purging rows |
| Migration | CHECK on status, on completed-iff-`completed_at`, and on the hash shape; the `user_id` foreign key is nullable with `nullOnDelete`, so the row outlives the user |
| No habit delete | `SPEC_AMENDMENTS.md` line 336 says there is no habit delete in v1. This phase did not add one, correctly |
| Legal | `privacy.md` section 7 already promised what A49 does; no change, no bump |

## 3. Findings

**L1 · Low · Completed deletion rows are never removed**
The packet's third question. A completed row holds only ids, times and a hash, but it has no use after its receipt expires. `accounts:purge` should also delete completed rows whose `receipt_expires_at` has passed. One Pest test and one mutant.

**I1 · Info · Other devices cannot tell a deletion from an expired session**
The packet's first question. The tokens are deleted, so the server cannot tell an old token from any unknown one, and a distinct code would only work during the minutes before the purge runs. The data that stays on another device is on the person's own phone, and they deleted the account knowingly. No change for v1. If it matters later, the fix belongs with milestone push (6.5): a silent "account gone" message to the account's devices before the tokens go.

**I2 · Info · One transaction for the whole purge**
The packet's risk. Fine at today's sizes; Phase 7's load test should purge a heavy account.

**I3 · Info · Password-reset rows must join the purge**
Phase 6.4 adds a table of reset codes. It must carry `user_id` (so the schema test catches it) and be in the purge order.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 L3 by health check, older kids not judged | Accepted. The health check stops a deploy on Render, which is where it matters |
| 2 `lockUser` on a missing user raises `AccountDeleted` | Accepted |
| 3 Exports take the lock through `lockUser` | Accepted |
| 4 `ClosePeriodsJob` skips a deleted account | Accepted |
| 5 `ApiClient.delete` | Accepted |
| 6 The account's files folder goes with its database | Accepted |
| 7 No keyboard submit on 28 | Accepted, and the right call: a destructive action needs the button |
| 8 28's export card in the warning ink | Accepted (design) |
| 9 Show/hide on the password | Keep it. The design does not draw it, but it helps people type a 12-character password correctly, it is the app's shared field, and it meets the 44 px rule |
| 10 Register answers 422 on `email` while the purge is pending | Accepted; the same answer as an existing account |
| 11 No change to the expired-session path | Accepted (I1) |
| 12 "Delete account" in the quiet text style | Accepted (design) |
| 13 ASSUMPTION(A48-phasing) now covers only Restore | Accepted |
| 14 Local only: dev DB migrated, API restarted | Accepted. None of it is in a commit |

## 5. Open questions (answered)

1. **A distinct code for other devices.** No, not in v1 (I1).
2. **A status screen for the receipt.** No. There is no design for one, and the purge normally finishes within minutes. Keep the stored receipt; it costs nothing.
3. **Pruning old deletion rows.** Yes, after the receipt expires (L1).

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 84 of `docs/DEVICE_GATE.md`.** It must be run before anyone outside the team installs the app.
- **Production needs a scheduler and a queue runner.** On Render's free tier neither runs on its own (see the release plan in the reply).
- **A timezone change can move the freeze watermark backwards** (from 5.1). No test.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **Dependabot has open branches.** Check CI and the generated diff before any merge.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Legal items, still yours: the facts in `docs/legal/facts.json` (now including the email provider and the host), the lawyer's reading, `status: final`, the Pages source and the first publish.
4. **The next phase is 6.4, password reset by a 6-digit code** sent through Brevo, because no domain is available for email links. Imports (6.3) and milestone push (6.5) follow after the first deployment. The order and the reasons are in the reply.
