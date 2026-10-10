# Phase 3.3 review (Terms of Service and Privacy Policy pages, consent record, app links)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-10
Scope: `ac419a4..b136a3f`. Read at code level: `legal-pages.yml`, `PageBuilder.php`, `scripts/build-legal.php`, the consent migration, the register changes (`AccountService`, `RegisterRequest`, the `contract-fixtures/auth/` fixture), `legal_config.dart`, `url_opener.dart`, `url_launcher_opener.dart`, `legal_links.dart`, the create-account screen, `auth_service.dart`, `main.dart`, the manifest `<queries>`, A33 in the amendments, the Phase 3.3 entry in BUILD_PLAN and the CLAUDE.md rule on `docs/legal`. I did not read the bodies of the 18 Pest legal tests or the nine new Flutter tests, I did not see the screenshots, and I did not run Pest, Dart or the mutation check (CI ran the first two; 23 of 23 mutants killed is the packet's figure).

## 1. Verdict

**Phase 3.3 is accepted.** The builder, the consent record and the app links do what A33 says. No code change is required. Two things change on my side (the Privacy Policy gains a GitHub Pages line and the contact blocks get hard line breaks; updated files are sent with this review). One gap I found while checking the device gate is new and goes into Phase 3b (N4: nothing in the app can sign out).

Publishing is still blocked, as intended. It needs the five empty facts filled and both documents set to `final`.

## 2. What I verified

| Check | Result |
|---|---|
| `b136a3f` is the head of `origin/main` | Yes. `git rev-parse HEAD` and `git rev-parse origin/main` both print `b136a3ffc761a8f3dc5d397c9c568d58c873f5d2` |
| CI run 38016590385 | Success on `b136a3f`, push, 2m50s: api 1m12s, docker-compose 6s, app 2m46s, e2e 1m10s. The run page shows only the overall result, not per-job status |
| "Legal pages" run 38016590396 | Success on `b136a3f`, push, 20s: build 16s, one artifact `legal-pages` (9.87 KB). A `deploy` job is listed with no duration or status. Its `if` is false on a push, so I infer it was skipped; the page does not say so. The only artifact is the build output, which fits |
| A push cannot publish | `deploy` has `if: github.event_name == 'workflow_dispatch' && inputs.publish`; the Pages upload step has the same condition; `--publish` is passed only under it |
| Publishing is blocked until the facts are filled | `PageBuilder::build` collects a problem for every non-final document and every null fact; with `$publish` it throws `LegalBuildException`, and `build-legal.php` exits 1 on it. Without `$publish` the same problems are warnings and the gap shows as `[[name]]` |
| Page safety | `html_input => escape`, `allow_unsafe_links => false`; fact values are HTML-escaped after the Markdown conversion; an unknown `{{token}}` fails the build; no script and no external resource in the template |
| Contrast and touch targets | Both palettes are the app's colour roles; seven text pairs are declared at 4.5:1 and a test checks them; footer links are 44 px tall |
| Consent record | Migration adds two `char(10)` versions and `legal_accepted_at timestamptz`, with CHECK regexes and a rollback that drops them. `AccountService::register` stores `legal_accepted_at` from the server clock. `RegisterRequest` requires both versions and checks their shape and that they are real dates. Nothing returns them (not `/me`, not the sync `user` entity) |
| App links | `LegalConfig.baseUrl` from `LEGAL_BASE_URL`, default `https://khayson.github.io/habit-system`; `ensureSafe()` is called in `main` and requires https in a release build. `UrlLauncherOpener` tries an in-app browser tab, then the external browser, returns a bool and never throws. `LegalLinks` shows a bottom sheet with the address and a "Copy link" button when neither opens |
| Versions are pinned | `LegalVersions.terms` and `.privacy` equal `2026-10-10`, the front matter of both documents; a test ties them together |
| Test counts | Flutter 407 to 416 is nine new tests, Pest `tests/Unit/Legal` 18 passed with 225 assertions, mutants 22 to 23. I take these from CI and the packet |

## 3. Findings

**N1 · Low · mine · The Privacy Policy did not say the pages are hosted by GitHub, and the contact blocks ran together**
Opening a page on GitHub Pages sends the visitor's IP address and request to GitHub, so §5 ("Who we share it with") needs a line for it. Separately, my contact blocks used plain line breaks, which Markdown joins into one line, so the address and the email printed on a single run-on line.
Fixed in the files sent with this review: a GitHub bullet in §5 (it also says the pages set no cookies and run no analytics), backslash line breaks in the contact blocks of both documents, a new claims row in the README, and the habit-name sentence in §3 now mentions the profile setting. The version is unchanged because nothing is published yet. After the first publication, any wording change bumps `version` and `LegalVersions` together (README rule 2).

**N2 · Low · The 404 page uses relative links**
`404.html` is built with an empty root, so its footer links are `terms/`, `privacy/` and `./`. On a project site, GitHub serves `404.html` at whatever path was missing: a request for `/habit-system/foo/bar` shows the page with links that resolve to `/habit-system/foo/terms/`, which is another 404. It is cosmetic, because the inline stylesheet still loads and the app never links to a missing path. Fix when the site gets its own domain (or before, with a `--base-path` option and root-absolute links on that one page). Carry to Phase 7.

**N3 · Info · The deploy path has never run**
`configure-pages@v6`, `upload-pages-artifact@v5` and `deploy-pages@v5` exist as tags and the other actions in the workflow ran in this CI run, but the three Pages actions have not executed. The first publish click is their first run. If it fails, the error will be about repository settings (Pages source or the `github-pages` environment's branch rule) rather than the code. Run it from `main`.

**N4 · Medium · Nothing in the app can sign out**
While checking `DEVICE_GATE.md` I searched for callers of `SessionProvider.signOut`. The only callers are tests (`session_end_test.dart`); no screen has a sign-out control and `app_en.arb` has no sign-out string. Step 15 of the gate ("Sign out") therefore cannot be performed on a phone, which is the same class of gap as K4. The 3.2c fix to sign-out (K3) is tested, but no user can reach it.
This is a scope gap on the architect's side: neither the plan nor the design file places a sign-out control before Profile (20), and the design's screen 20 shows "Signed in as {email}" with no sign-out row. Fix in Phase 3b: a Sign out row on 20 (design gap, to be marked ASSUMPTION). Gate step 15 is run after 3b. Steps 1 to 14 and 16 to 19 can be run now.

**I1 · Info · The server records a version, it does not judge it**
`RegisterRequest` checks that each version is a real `YYYY-MM-DD` date. It cannot know which versions have been published, so a client could send an old or invented date, and that is what gets stored. That is the right contract for "which text the person was shown", and it is enough for the Phase 7 re-consent flow, which compares the stored version with the current one. No change.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 Legal files moved from `docs/reviews/legal` to `docs/legal` | Accepted. It was a one-off authorisation from Khay Studios (rule 8 otherwise forbids writing into `docs/reviews/`), and the contents are unchanged. The files in this review's output are the ones to copy into `docs/legal/` |
| 2 `league/commonmark` constraint `>=2.10.3 <3.0` | Accepted; it is equivalent to `^2.10.3`. The `composer.lock` change of `plugin-api-version` from 2.6.0 to 2.9.0 is noise from the Composer version |
| 3 `url_launcher ^6.3.3` | Accepted |
| 4 Manifest `<queries>` (VIEW https and the Custom Tabs service) | Accepted; Android 11 and later needs it for the browser lookups |
| 5 New `contract-fixtures/auth/` for the register request | Accepted; PHP and Dart both read it |
| 6 `urlOpener` seam | Accepted; it is what makes the fallback sheet testable |
| 7 `LegalLinks` as two text buttons plus a fallback sheet (ASSUMPTION A33-links) | Accepted as a design gap. The design says "external configured destinations" and shows no fallback |
| 8 Strings written by Claude Code | Accepted |
| 9 Screenshot methods (iframe wrapper pages for the web pages; `LEGAL_BASE_URL=nohandler://legal.invalid` to force the fallback sheet) | Accepted |
| 10 No TaskCreate in the session | Accepted |

## 5. Answers to the packet's open questions

1. **Should the Privacy Policy mention GitHub?** Yes, and it now does (N1). Do this before `status: final`.
2. **The default base URL points at a site that is not published.** Keep it for development builds. The links open GitHub's 404 page until the first publish, which is harmless before release. The release check belongs to Phase 7: both URLs must return 200 before a release build is cut (README pre-release item 6 already requires the pages to be published).

## 6. Risks to keep in view

- On Android the fallback sheet will rarely appear, because `url_launcher` falls back to its own in-app WebView before it reports failure. The sheet is a safety net for devices with no browser at all.
- A build from before this phase cannot register, because the old request has no versions. Correct before release.
- A text change that is not accompanied by a `version` bump is a legal-record bug. The pin test catches a mismatch between the app and the files, not an edit made to both.
- Until the five facts are filled and a lawyer has read both texts, nothing can be published, and no store listing can link them.

## 7. Next steps

1. **Khay Studios, now.** Copy `terms.md`, `privacy.md` and `README.md` from this review's output into `docs/legal/` (not `docs/reviews/legal/`) and commit. The CI legal tests read these files, so its result will tell you if anything broke.
2. **Fill `facts.json`:** `contact_email`, `postal_address`, `governing_law`, `hosting_provider`, `hosting_region`. Confirm the defaults I chose: app name "Habit System", publisher "Khay Studios", minimum age 16, technical logs kept 30 days, no marketing emails.
3. **Before release:** a lawyer reviews both texts (the Privacy Policy cites Ghana's Data Protection Act, 2012 (Act 843) and the Data Protection Commission); set `status: final` and `effective` to the release date; in the repository settings choose Pages, Source: GitHub Actions; run "Legal pages" from `main` with publish ticked.
4. **Device gate:** run steps 1 to 14 and 16 to 19 of `docs/DEVICE_GATE.md` on a real Android 13+ phone. Step 15 waits for Phase 3b (N4).
5. **Phase 3b** (profile photo and location, Profile screen 20, sign out), with L1 and L2 from the 3.2c review in its Part 0. The prompt is in the reply.
6. Add `PHASE_3_1_REVIEW.md`, `PHASE_3_2B_REVIEW.md`, `PHASE_3_2C_REVIEW.md` and this file to `docs/reviews/` yourself.
