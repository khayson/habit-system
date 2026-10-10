# Phase 3b.2 review (Profile screen, photo and location in the app, sign out, hidden habit names; server follow-ups)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-10
Scope: `92e0e0d..8b1bbc7` (24 commits, 73 files). Read at code level: the server follow-ups (`AvatarPipeline` constants, `ProfileRules`, `EntityPresenter`, `Countries` and config), `AvatarSync`, `PhotoService`, `HttpAvatarTransport`, `ProfileView`, `updateProfile` in `LocalMutationService`, the v7 schema diff, the diffs of `sync_engine.dart` (upload step and lease fix), `workmanager_sync.dart`, `background_sync.dart`, `account_context.dart`, `database_opener.dart`, `main.dart`, `reminder_scheduling.dart` (Hide habit names), `router.dart`, `app_shell.dart`, `AndroidManifest.xml`, `Info.plist` and `pubspec.yaml`; `profile_screen.dart` and `profile_sheets.dart` in full; the picker; the e2e profile and photo scenarios; the names of the new tests; and the design file's flow note for screen 20. I did not read the bodies of the Flutter and Pest tests, `AvatarView`, the screenshots or the generated drift file, I did not run any check, and I did not open the two failed CI runs (their account is the packet's).

## 1. Verdict

**Phase 3b is accepted.** Together with 3b.1 it meets the Phase 3b gate in BUILD_PLAN: EXIF and GPS stripped, oversized, polyglot and decompression-bomb inputs refused, cross-owner read refused, the photo shown offline and uploaded after reconnect (proved over a real multipart PUT, which closes P4), and the avatar objects removed by `deleteAllFor` (the purge job that calls it is Phase 6). No finding blocks the next phase. Four Low findings and two Info items below; they ride along as a small Part 0 of whatever Claude Code builds next.

## 2. What I verified

| Check | Result |
|---|---|
| `8b1bbc7` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `8b1bbc740f2f1dc531e6c9f2ea3916e93848440d` |
| CI run 38062895899 | Success on `8b1bbc7`, push, 2m51s: api 1m10s, docker-compose 6s, app 2m48s, e2e 1m10s. The run page shows only the overall result |
| Test counts | Pest 541 passed with 5 skipped (the pipeline test has a Linux-only guard at line 168, which fits the five per-type memory tests; they run in CI), Flutter 419 to 454, mutants 30 of 30 (unchanged). From the packet |
| S1 | `has_avatar` is `avatar_key !== null` in the one presenter that feeds `/me`, the bootstrap and the journal. The key and hash are still absent |
| S2 | `api.countries_path` defaults to `resource_path('countries.json')`; three byte-identical copies written by the script; the packet reports a parity test on each side |
| S3 | One `noControlCharacters()` closure shared by `name()` and `city()` |
| S4 | Per-type constants are 9 (JPEG), 10 (PNG), 10 (WebP), plus 4 for a quarter turn. The measured values (4.1, 7.1, 8.1, 7.1, 8.3 bytes a pixel) fit under them with 20 to 25 percent margin. This closes P1. Note the cost: under a 128M `memory_limit` only about 11 megapixels of JPEG pass |
| Upload queue | The row is the Idempotency-Key. The cycle is outbox, then uploads, then a pull (`continue` after an acknowledged upload), then `refreshCache`, so `refreshCache` always reads a user entity that is newer than the upload. 5 minutes minimum between attempts, doubling to 6 hours; `Retry-After` honoured and never below 5 minutes; 401 stops the run and the row stays queued; a row is removed only by an acknowledgement, a newer choice, or a refusal |
| A newer choice | `PhotoService` replaces unsent and refused rows and their files in one transaction. An in-flight upload that is replaced is acknowledged harmlessly (`current == null`) and the newer choice uploads next |
| Other devices | `has_avatar` false clears the pointer; true with a newer `avatar_version` fetches `md` once; a device never downloads its own upload (`avatarFileVersion` is set from the acknowledgement); files not pointed at are collected, and a fresh local choice is protected for ten minutes |
| Account isolation | `filesRoot` is `{support}/{database name}_files`, one folder per account, the same in the foreground and in the WorkManager isolate. `_collect` only lists that folder, so it cannot touch another account's files |
| `profile.update` | Always carries the three keys. A second unsent edit coalesces into the first and keeps its base version. The view lays the unsent edit over the confirmed user and never writes it into the confirmed row (invariant 9) |
| Profile screen | Reads local data only. Rows are Timezone, Reminders and "Signed in as"; 21 and 22 are not drawn. Sign out confirms only when something is unsynced (outbox plus pending uploads) and then calls `SessionProvider.signOut`, so step 15 of the gate can now be run. Terms and Privacy links are `LegalLinks` |
| Hide habit names | Stored per account in `local_settings`, default off by a named constant. The toggle cancels every scheduled notification of the account, clears `scheduled_notifications` and replans, because the plan's diff compares fire times only. The body is generic; the title is generic while hidden |
| e2e | The photo scenario runs offline then online, uploads over a real multipart PUT with the Dart transport, checks WebP 96, 160 and 320, `avatar_version` 1, B caches `md-1.webp`, another account gets 404, and removal clears `has_avatar` and deletes B's copy |
| Manifest and plist | `UCropActivity` declared; camera and photo usage strings present. I could not build iOS |

## 3. Findings

**R1 · Low · A picker or cropper failure is not handled**
`showPhotoSheet` calls `picker.pick(...)` and `photos.choose(...)` without a `try`. If the user denies the camera permission (iOS), the cropper fails or the disk is full, the exception goes uncaught and the user sees nothing. The same pattern: `_save` in the edit sheet rethrows after clearing its flag, and the Hide-names switch is not put back if saving fails. Fix: catch around the pick and the write in the photo sheet and show one neutral line ("We couldn't open the camera. You can allow it in your device settings." / "That photo couldn't be added. Try another."); revert the switch on failure. One widget test with a throwing fake picker.

**R2 · Low · Every 4xx except 401 and 429 is treated as "this photo is refused"**
`HttpAvatarTransport` maps all other 4xx answers to `rejected`, and `AvatarSync` then marks the upload rejected, drops the shown photo and tells the person to choose another. That is right for 413 and 422 (the photo itself is wrong). It is wrong for a 404 from a server that does not have the endpoint yet, a 403 from a proxy, a 400 or a 408: the photo is fine and the person is told otherwise. Fix: `rejected` only for 409, 413, 415 and 422; every other status backs off like a 5xx. Test: a 404 and a 403 stay queued with a later `nextAttemptAt` and the photo stays shown.

**R3 · Low · The lease fix covers three statements; the engine's other plain writes are exposed to the same refusal**
The fix wraps `_acquireLease`, `_renewLease` and `_releaseLease` in the retried transaction, with a test that failed on the old code. If the cause is as the packet says (SQLite refusing a plain write at once, without waiting for `busy_timeout`), the same refusal can hit `_updateState` (17 call sites through one helper), `_update` and `_setState` in the engine, and `_updateState`, `_defer` in `AvatarSync`. A refusal there ends the run with an error and the next cycle repeats the work, which is safe (uploads are idempotent), so no data is lost, but it will show as a flaky sync. Fix: route those helpers through one retried-write helper on `AppDatabase`, and add a test that drives a refusal at one of them.

**R4 · Low · The photo may carry GPS on the phone and on the way to the server**
`requestFullMetadata: false` is about permissions, not metadata. I believe the Android cropper (uCrop) copies the source photo's EXIF tags, GPS included, into its output file (and sets the orientation tag to 0); I did not verify it. If so, the prepared JPEG kept on the phone, and the one uploaded, carry location data. The server removes it, so the Privacy Policy's claim about our storage holds, but the app should not send or keep what it does not need. Fix: a small bounded pure-Dart scrubber in `PhotoService.choose` that drops APP1 (EXIF and XMP), APP13 (IPTC) and comment segments from the prepared JPEG, written like `JpegOrientation` (never throws; unreadable input is kept as it is). Tests with a JPEG that has a GPS segment. Add a gate step: a portrait photo taken with the phone camera comes out upright.

**I1 · Info · A habit's name in a scheduled notification goes stale on rename (carry to Phase 4)**
The plan's diff skips a notification whose fire time is unchanged, so after a habit is renamed the already-scheduled reminders keep the old name until their time changes. There is no rename in the app yet (Edit habit, 09, is Phase 4). Phase 4's Part 0 must make the replan compare the text as well, or replace a habit's notifications when its name changes.

**I2 · Info · The Timezone row shows the IANA id; the design shows a name**
The packet says the design shows the id. The design's flow note next to 04 reads "Pacific Time → Edit", a name. The standing assumption A2b2-zone-name already shows the city taken from the id on screen 04 ("Los Angeles", with the id beneath). Use the same helper for the row on 20 (the city as the line, the id in the accessibility label). One line and one test.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 `image_picker`, `image_cropper`, `UCropActivity`, iOS usage strings | Accepted. The strings are accurate. iOS is unbuilt, to be checked in Phase 7 |
| 2 `scripts/measure-avatar-memory.php`; `E2E_PHP` | Accepted |
| 3 User fields stay in the `user_payload` JSON; only the photo pointer has columns | Accepted; it keeps the tolerant reader and avoids a second copy of the user |
| 4 Engine lease fix outside the list | Accepted as necessary for green CI; see R3 |
| 5 No failing-first test for S7 | Accepted. The packet explains why the harness cannot observe the gap and says two setups were tried; the flag is now held until the screen is gone, which makes the question moot |
| 6 `NoticeBanner` shared; screen 18 also names "Time zone" | Accepted |
| 7 Waiting states on 20 use an icon and words, not `StatusChip` | Accepted: symbol plus text, wraps at scale 2. The initials in the avatar do not scale, which is normal for an avatar; the label carries the name |
| 8 Design gaps (edit sheet, "Edit profile" button, sign out, Terms and Privacy on 20, copy-link note, "Waiting to upload") | Accepted |
| 9 Level and XP line omitted | Accepted; Phase 5 |
| 10 Privacy and export (21) and Archived habits (22) not drawn | Accepted |

## 5. Answers to the open questions

1. **EXIF on the phone.** Our server storage claim stands, so `docs/legal` needs no change today. Rather than add a sentence about the phone copy, strip the metadata on the device (R4): then the claim is true at both ends and §6 stays as it is. If you would rather not write the scrubber, the alternative is one sentence in Privacy §6 that a copy of the chosen profile photo is kept on the phone, and the version bumps with it (nothing is published yet, so that is free). My recommendation is the scrubber.
2. **Timezone row.** The design shows a name, not the id (I2). Use the city helper from 04.

## 6. Risks to keep in view

- **Version conflicts.** An avatar change bumps `users.version`, so a `profile.update` queued on another device in that window lands in screen 18.
- **Production memory.** With the new constants, a 128M `memory_limit` admits about 11 megapixels of JPEG. The app sends at most 1024 px, so only other clients feel this. Size the API workers (512M and a worker count against memory) in Phase 7.
- **Phase 7 deployment limits.** `upload_max_filesize` and `post_max_size` of at least 6M and a proxy that allows the body, from the 3b.1 review.
- **Real-device behaviour is unproven.** Reminders, background sync, the camera, the cropper, sign out and hidden names have only run on an emulator and in tests. The device gate is the check for that.
- **Dev data.** Test accounts remain in the dev database; the e2e uses a second server with the breach check off because of a local certificate problem.

## 7. Next steps

1. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone: steps 1 to 14 and 16 to 25 (step 15 now works through Profile → Sign out). Record each result; failures come back as findings.
2. Commit the review files in `docs/reviews/`, including this one and `PHASE_3B1_REVIEW.md`.
3. The remaining items from earlier reviews are still yours: the five facts in `docs/legal/facts.json`, the lawyer's reading, `status: final`, Pages source and the first publish.
4. Phase 4 with R1 to R4, I1 and I2 in its Part 0 (the prompt follows in the reply).
