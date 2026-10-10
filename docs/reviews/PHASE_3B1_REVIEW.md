# Phase 3b.1 review (profile.update, avatar pipeline, store and endpoints; L1 and L2)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-10
Scope: `b136a3f..92e0e0d` (14 commits, 40 files). Read at code level: `AvatarPipeline`, `JpegOrientation`, `AvatarService`, `AvatarStore`, `AvatarController`, `ProfileUpdate`, `ProfileRules`, `Countries`, the migration, the diffs of `routes/api.php`, `config/api.php`, `EntityPresenter`, `MutationApplier`, `RegisterRequest`, `ci.yml` and `composer.json`, `Images.php` (the test image builders), `gen-countries.php`, the country file's shape and a spot-check of its names, the diff of `reminder_editor_screen.dart`, the names of the new tests and mutants, and the bodies of the pipeline's memory, cap and orientation tests. I did not read the bodies of the other Pest tests, I did not run Pest, Pint, Larastan, the mutation check or the curl run (CI ran the first three; the 30 of 30 is the packet's figure), and I did not run any image through the pipeline myself.

## 1. Verdict

**Phase 3b.1 is accepted.** The pipeline checks run in a safe order, the store cannot reach outside the caller's folder, the endpoints are owner-only by construction, and the profile mutation follows the same pattern as the other user-entity writes. Nothing blocks 3b.2. Four Low findings and one Info below are small server follow-ups; they go into a short Part S0 at the start of 3b.2. Two of your three open questions change the server (answers in section 5).

## 2. What I verified

| Check | Result |
|---|---|
| `92e0e0d` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `92e0e0da38d339eba3c1aa6445ac483af40c7b2f` |
| CI run 38044173687 | Success on `92e0e0d`, push, 2m44s: api 1m19s, docker-compose 7s, app 2m40s, e2e 1m21s. The run page shows only the overall result |
| "Legal pages" run 38044173738 | Success on `92e0e0d`, push, 20s: build 17s, and a `deploy` job listed with 0s and no result shown. A push cannot deploy (the job's `if` needs a manual run), so I take it as skipped; the page does not say |
| Test counts | Pest 529, Flutter 416 to 419 (the three new L1/L2 tests), mutants 23 to 30. From the packet and CI |
| Check order in the pipeline | 5 MB cap, then type by content (finfo), then header dimensions with `getimagesizefromstring` (the header type must match finfo), then the 25 MP cap, then the memory estimate, and only then `imagecreatefromstring`. A hostile header is refused before any pixel is allocated |
| Output | Encoded from pixels at 96, 160 and 320 px, so metadata and appended bytes do not survive. The original is never returned. The hash is that of the lg bytes |
| Orientation parser | Bounded (512 segments, 64 KB APP1, 256 IFD entries), every read goes through `u16`/`u32`, which return -1 outside the buffer, and a value outside 1 to 8 gives 1. I traced the mapping for all eight orientations against the EXIF definitions: 2 flip horizontal, 3 flip both, 4 flip vertical, 5 flip horizontal then 90° counter-clockwise, 6 270° counter-clockwise, 7 flip horizontal then 270°, 8 90°. All eight are correct (see P2 for the test gap) |
| Store | Keys are `avatars/{user}/{uuid}-{sm\|md\|lg}.{webp\|jpg}`; `owns()` requires the caller's id, a UUID and the `-lg` suffix; reads and deletes refuse anything else; `deleteAllFor` checks the id is a UUID before it removes a directory |
| PUT order | Replay check, pipeline, write the new objects, one transaction under the user lock (columns, both versions, journal row, receipt), then delete the old objects. A failed transaction removes the new objects; a failed delete is logged. A second request with the same key that finishes while this one decodes returns the stored result and removes its own objects |
| Owner scope | The routes have no id: every action acts on `$request->user()`. An unknown size answers 404 only after authentication |
| Rate limit | `throttle:avatar-upload` follows `auth:sanctum`, so the bucket is per user. The limiter and its config already existed |
| profile.update | Owner check (404), `base_version` required, version check with the current user in the conflict, identical update acks without a bump, journal row in the same transaction (trigger test), name rule shared with registration |
| User entity | Gains `city`, `country_code`, `avatar_version`. `avatar_key` and `avatar_sha256` are not in the presenter |
| CI | `gd` added to both extension lists (api and e2e) and `ext-gd` to `composer.json`. The CI run passed, so its GD has WebP |
| L1 and L2 | Three tests, each red on the old code and green now. `_saving` guards Save and Remove, and a missing reminder id goes to 12 |
| Countries | 250 rows (249 ISO codes plus XK), unique, CLDR names unedited, e.g. "Côte d’Ivoire", "Palestinian Territories", "Taiwan", "Kosovo" |

## 3. Findings

**P1 · Low · The memory estimate was measured on one kind of file**
The packet's figure (+97.7 MB for 25 MP) comes from a flat-colour baseline JPEG that GD itself wrote; the exact-cap test uses the same. PNG, WebP and progressive JPEG decode through different libraries (libpng, libwebp, libjpeg's coefficient buffer) and I expect some of them to hold a second large buffer while GD builds its image. I could not confirm that from the repo, so this is a gap in the measurement, not a proven bug. The failure mode matters: a file that is allowed by the checks but needs more than the estimate ends in a PHP fatal error or an out-of-memory kill (a 500), not the clean 422. It needs an account and is limited to 10 uploads an hour, and the app never sends such files (it sends a downscaled JPEG).
Fix: measure the peak memory growth (on Linux, `VmHWM` from `/proc/self/status`, so memory outside PHP's allocator counts) for a 25 MP baseline JPEG, progressive JPEG, 8-bit RGBA PNG, interlaced PNG and WebP; set a bytes-per-pixel constant per type from the worst measured value with a margin; add a test per type at a smaller size (about 4000 × 4000) that the estimate is at least the measured growth. Put the measured table in the packet.

**P2 · Low · Only orientation 6 is tested**
The mapping is right on my reading (section 2), but nothing pins 2, 3, 4, 5, 7 and 8. The orientation mutant breaks only one of them. A later edit to `orient()` could swap two quarter turns without a failing test. Fix: one dataset test over all eight orientations with a square image of four coloured quadrants (stored TL red, TR green, BL blue, BR yellow). Expected displayed corners, TL / TR / BL / BR: 1 = R G B Y; 2 = G R Y B; 3 = Y B G R; 4 = B Y R G; 5 = R B G Y; 6 = B R Y G; 7 = Y G B R; 8 = G Y R B.

**P3 · Low · A name may contain control characters; a city may not**
`ProfileRules::name()` is `required|string|max:80`, unchanged from registration, so a newline or a tab is accepted and later shown in a header, an avatar label and a notification. Fix: apply the same no-control-characters check the city already has to `ProfileRules::name()`, with a test on both `register` and `profile.update`.

**P4 · Low · The real PUT path has no automated test**
PHP does not fill `$_FILES` for PUT, so production uploads go through `request_parse_body()` in the controller's fallback. The Laravel test client cannot reach that branch, so only your manual curl run covers it. The app will use exactly this path. Fix: the 3b.2 end-to-end test must upload through the real client over real HTTP as a multipart `PUT` (not a POST with a method override), and that test is a gate item.

**I1 · Info · Re-enabling the buttons before the screen is gone (screen 11)**
`_save` clears `_saving` and then calls `_leave()`. I believe Flutter ignores taps on a route that is popping, so a double tap during the pop animation is probably harmless, but I did not test it. Keeping `_saving` true after a successful write (clear it only on failure) removes the doubt at no cost. Take it with the next change to that file.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 `gd` in both CI extension lists, `ext-gd` in `composer.json` | Accepted |
| 2 `composer.lock`: phpdotenv's source URL changed after the repository was renamed | Accepted; noise, same commit |
| 3 Nine bytes a pixel for orientations 5 to 8 | Accepted, subject to P1 |
| 4 `request_parse_body()` for multipart PUT | Accepted; P4 |
| 5 Avatar size check in the controller rather than a route constraint | Accepted; it keeps the route-wide auth test meaningful |
| 6 New fixtures are PHP-suite only until 3b.2 | Accepted; the Dart suite must read both in 3b.2 |
| 7 New config keys `api.avatar_disk` and `api.countries_path` | Accepted; `countries_path` changes (Q3) |
| 8 No mutant for the replay check; seven mutants instead of eight | Accepted. The second replay check inside the transaction masks a missing first check, so no observable behaviour kills it |
| 9 ASSUMPTION markers A3b-countries-xk, A3b-location-optional, A3b-avatar-paths, A3b-avatar-format | Accepted |

## 5. Answers to the open questions

1. **`PATCH /me`.** Agreed: do not add it. The app writes profile changes through `/sync` (A14) and no client needs the REST adapter. A20's line "PATCH /me stays as the REST adapter" is stale; 3b.2 adds a one-line clarification to A20 saying so.
2. **A removed photo.** Add a boolean `has_avatar` to the user entity (true while a photo exists). Without it a new device sees `avatar_version` 3 and must request the photo to learn there is none, and every client has to treat a 404 as "no photo". With it the rule is simple: `has_avatar` false means show initials and clear the cached file; true and a newer `avatar_version` means fetch once. It is an additive field, so older clients are unaffected.
3. **The country file at runtime.** Do not read a path outside `api/`. The server gets its own copy at `api/resources/countries.json` (default for `api.countries_path`). `gen-countries.php` writes the canonical `contract-fixtures/profile/countries.json`, the server copy and the app's asset copy in one run, and each suite has a test that its copy equals the canonical file, so they cannot drift.

## 6. Risks to keep in view

- **Production limits.** `upload_max_filesize` and `post_max_size` must be at least 6M, and the reverse proxy must allow the body (nginx's default `client_max_body_size` is 1M and would answer HTML). Phase 7 deployment checklist.
- **Concurrent decodes.** Each in-flight 25 MP decode can take hundreds of MB. Size the worker count against memory in Phase 7; the 10-an-hour limit helps but does not bound concurrency.
- **Upload budget.** Every PUT counts toward the 10 an hour, including replays and failures. The app's retry must be slow (3b.2 sets a five-minute floor) and honour `Retry-After`.
- **Version conflicts.** An avatar change bumps `users.version`; a `profile.update` queued on another device in that window lands in screen 18, like a calendar change today.
- **Orphans.** If deleting the old objects fails after commit, they stay until the account purge calls `deleteAllFor` (Phase 6).
- **Dev data.** The curl test account's avatar under `storage/app/private/avatars/` is harmless; no storage file is in the diff.

## 7. Next steps

1. Run the device gate steps 1 to 14 and 16 to 19 if you have not yet (step 15 waits for sign out in 3b.2).
2. Phase 3b.2 with the prompt in the reply: a short server Part S0 (P1 to P3, `has_avatar`, the server's own country file, the A20 clarification), then the app (data layer, Profile screen 20, photo picker and crop, sign out, "Hide habit names"), then the end-to-end test.
3. Commit the review files yourself (`docs/reviews/`), including this one.
