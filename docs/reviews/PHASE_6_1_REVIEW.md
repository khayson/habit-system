# Phase 6.1 review (exports: screens 21, 29 and 30)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-25
Scope: `ce742b3..0ff6f94` (18 commits, 63 files, +3,498 / −33). Read at code level: `ExportController`, `RunExportJob`, `ExportStore`, `ExportBuilder`, `CanonicalJson`, `CsvWriter`, `ManifestSigner`, `ManifestCheck`, `ExpireExports`; the route, config, scheduler, `phpunit.xml` and CI diffs; A48; the privacy diff; on the app, `ExportService`, `FileSharer`, the router diff, and the polling and download parts of `export_status_screen.dart` and `privacy_screen.dart`. Read by name only: the Pest, Dart and e2e tests, the fixtures, the screens' layout code. Not read: the generated l10n files. I compared the screens with design 21, 29 and 30. I did not see the screenshots and did not run any suite.

## 1. Verdict

**Phase 6.1 is accepted, with one Medium finding to fix first in 6.2.** The export is a signed, owner-only, read-only snapshot; the signature binds the user, the snapshot and every file; the CSV neutralises formulas; the download needs both the session and the signature; nothing secret goes into a file. The Medium finding is a stuck job: a worker that dies mid-export leaves the job `running` for ever, and since a second request returns the open job, that person can never export that format again. Four Low findings and three Info notes.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `0ff6f941370d3b69d3149c12be720c43178d5ef9`. 18 commits; the first is `bfb5864`, and `PHASE_5_3B_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Run 40145914133 on `0ff6f94`: success, push, 4m38s: api 2m03s, docker-compose 7s, app 4m34s, e2e 2m01s. The page shows only the overall result and the job times |
| Test counts | From the packet: Pest 686 passed (5 skipped), Flutter 812 (was 784), mutation check 57 of 57 (five new) |
| 5.3b carry-overs | Insights refetches when unacknowledged `habit_log` rows drop to zero and shows "Couldn't refresh right now." with Try again on a failed refresh (`0b98bb5`) |
| Routes | `POST /exports` behind `auth:sanctum` and `throttle:exports` (6 per hour); list, show and download behind `auth:sanctum` and `throttle:api` |
| Request | Under the user-row lock, an open job of the same format is returned; otherwise a new queued job is inserted and dispatched after commit |
| Ownership | Every read goes through `owned()`, which matches id and `user_id`; a non-UUID or someone else's id is the same 404. `ExportStore` checks the `exports/{user_id}/{uuid}.{zip|csv}` shape on every read and delete |
| Download order | Owner (404), expired or past `expires_at` (410 `export_expired`), not ready (404), signature (403), then a private, no-store stream. A ready job past its time is presented as expired before the sweep runs |
| Snapshot | One transaction set to REPEATABLE READ READ ONLY as its first statement; `snapshot_seq` is `change_seq` read inside it |
| Contents | Profile (name, email, city, country), timezone history, habits through the entity presenter, live logs with notes, reminders, XP entitlements and ledger, freeze ledger, usages and policy versions; the avatar from `AvatarStore`. No password, token, push token or device field is read |
| Manifest | Signed over the canonical JSON without `signature`, with `kid` inside the signed part; verification uses `hash_equals`; an unknown `kid` fails. Keys come only from config |
| CSV | A user cell starting with `=`, `+`, `-`, `@`, tab or carriage return gets a leading `'`, then RFC 4180 quoting. `completed` comes from `completed_at`, never recomputed |
| Failure | Any exception marks the job failed with `export_failed`, removes a written object and logs only the exception class |
| Expiry | `exports:expire` every 15 minutes deletes the object and moves ready to expired |
| App | `ExportService` reads with the tolerant reader; download goes to a temporary folder, the share sheet, then deletion of the folder; polling every 5 s with the timer cancelled on dispose and when the job is no longer pending; Retry is keyed by job id |
| Legal | `privacy.md` says what an export holds and that the file is deleted after 24 hours; version 2026-10-24, with `register_request.json` and the app's pin following it (A33) |

## 3. Findings

**M1 · Medium · A job that dies while running blocks that format for ever**
`RunExportJob` catches exceptions, but a killed worker, a timeout or an out-of-memory error ends the process before `catch` runs. The job stays `running`, `POST /exports` keeps returning it, and the person can never request that format again. A job that stays `queued` because no worker runs has the same effect. Fix: (a) add the queue's `failed()` hook to mark the job failed with `export_failed` and delete any object; (b) the 15-minute sweep also marks failed any `running` job not updated for 30 minutes and any `queued` job older than 24 hours; (c) `POST` ignores such stale jobs and starts a new one. Failing tests first for each, and one mutant (the stale check removed).

**L1 · Low · Screen 21 belongs inside the shell**
Design 21 draws the bottom bar with Profile selected; 29 and 30 do not. The packet's deviation 1 is right for 29 and 30 only. Put `/privacy` inside the shell with Profile selected (as 16 and 17), keep 29 and 30 outside.

**L2 · Low · The download follows whatever host the server names**
`download_url` is made absolute with the server's `APP_URL`, and the app passes it to Dio, whose auth interceptor adds the bearer token. A wrong `APP_URL` (for example `localhost` on a phone) breaks the download, and a misconfigured host would receive the person's token. Fix in the app: take only the path and query from `download_url` and send them to the configured API base; refuse a URL whose host differs from that base. A Dart test with a foreign host.

**L3 · Low · Nothing stops production from signing with the public test key**
The test key is in `phpunit.xml`, CI and `api-serve.ps1`. If it reached production, anyone could sign a "verified own export" and skip the 30-day backdate limit (A16). Fix: outside `local` and `testing`, refuse at boot (or in the health check) a current key whose secret equals the published one or is shorter than 32 bytes, and log clearly when no key is set, rather than failing every export quietly. Pest tests for both.

**L4 · Low · An expired link needs its own message**
The packet's first question. When the download answers 410 `export_expired`, reload the list and show "This download has expired. Request a new export." in place of the neutral error. One widget test.

**I1 · Info · The whole export is built in memory**
`build` returns the bytes and the store writes them in one call. Fine for v1 sizes; Phase 7's load test should include an export of a heavy account.

**I2 · Info · The photo is read outside the database snapshot**
The avatar comes from the object store, which the transaction cannot freeze. A photo changed during the build could pair with the older `avatar_version`. Harmless; no action.

**I3 · Info · The copy guard's new exceptions are exact strings**
"failed" and the two screen-30 sentences are design-verbatim and matched exactly, so the guard still catches new wording. Accepted.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 21, 29 and 30 outside the shell | Partly accepted: right for 29 and 30, not for 21 (L1) |
| 2 `share_plus` 13.3.1; `crypto` as a dev dependency | Accepted |
| 3 `register_request.json` `privacy_version` follows privacy.md | Accepted. That is what A33 requires; the credentials are untouched |
| 4 `LegalConsentTest` reads versions from the fixture | Accepted |
| 5 Copy-guard allowlist | Accepted (I3) |
| 6 CI and dev tooling (queue command, test key, `.env.example`) | Accepted, with L3 |
| 7 Pint fix in a mutant | Accepted |
| 8 ASSUMPTION(A48-phasing): Restore and Delete account hidden | Accepted; Delete arrives in 6.2 |
| 9 Local only: dev DB migrated, API on 8001, screens.43c used | Accepted. None of it is in a commit |

## 5. Open questions (answered)

1. **A 410 from the download.** Give it its own message (L4).
2. **Toast or floating SnackBar.** I have no record of this question in my reviews. Put it in the next packet with the screen and the message it is for, and I will answer it there. Until then, nothing changes.
3. **Free hosting, a code-based reset, and Firebase.** These are Khay Studios' decisions, answered in the reply that carries this review, not here. 6.4 and 6.5 do not start until they are confirmed and written into an amendment.

## 6. Risks to keep in view

- **The device gate is unrun: steps 1 to 14 and 16 to 78 of `docs/DEVICE_GATE.md`.**
- **Exports need a running queue worker and scheduler in production.** Without them every export stays queued (M1's sweep turns that into a visible failure rather than a silent wait).
- **The signing key is a long-lived secret.** Rotating it by `kid` keeps old exports verifiable only while the old key stays in `EXPORT_SIGNING_KEYS`.
- **A timezone change can move the freeze watermark backwards** (from 5.1). No test.
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **Dependabot has open branches.** Check CI and the generated diff before any merge.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone, steps 46 to 78.
2. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
3. Legal items, still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, the Pages source and the first publish.
4. **Phase 6.2 is account deletion (screen 28),** with M1 and L1 to L4 first. The prompt follows in the reply.
