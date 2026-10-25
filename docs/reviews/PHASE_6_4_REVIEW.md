# Phase 6.4 review (password reset by a 6-digit code)

Reviewer: Claude (architect/reviewer) for Khay Studios · Date: 2026-10-25
Scope: `1ebed79..2bfab04` (15 commits, 46 files, +2,134 / −35). Read at code level: `PasswordResetService`, `ResetCodeHasher`, `PasswordResetController`, `ResetPasswordRequest`, the `password_reset_codes` migration, the route diff, the `password-reset` rate limiter, the `PurgeAccounts` change, and the email normalisation in the register, forgot and reset requests. Read by the packet and by name only: the tests, the mail class, the app screens and providers, A50, the legal diff. I did not see the screenshots and did not run any suite.

## 1. Verdict

**Phase 6.4 is accepted.** A code is six random digits, stored only as an HMAC, valid for 15 minutes and 5 tries, replaced by a new one, and redeemed under the user lock in the same transaction that changes the password and signs out every device. Every email gets the same answer. One Low finding and three Info notes.

**CI is the packet's word again.** The GitHub run page for 40187854370 was refused from my side, as it was for 6.2. I verified the head SHA only. If you can, open the run in your browser once and confirm it shows four green jobs.

## 2. What I verified

| Check | Result |
|---|---|
| Head | `git rev-parse HEAD` and `git rev-parse origin/main` both print `2bfab04a50ba11f32fd80a6c11f23f8c170c0e7d`. 15 commits; the first is `6a0b955`, and `PHASE_6_2_REVIEW.md` in the tree is byte-identical to the file I sent (`diff -q`) |
| CI | Not verified by me. The packet reports run 40187854370 with every job `completed success` |
| Test counts | From the packet: Pest 728 (723 passed, 5 skipped), Flutter 845 (was 832), mutation check 70 of 70 (seven new) |
| 6.2 L1 | `accounts:purge` deletes completed deletions whose receipt has expired |
| Issue | The lookup skips deleted accounts; the code is drawn with `random_int` and padded, and hashed on every path, known email or not; under the lock, a code issued less than 60 s ago means nothing is sent; otherwise the unused code is replaced. A deleted account caught by the lock returns nothing |
| Redeem | Under the user lock and a row lock on the open code: expired, exhausted or missing fail; a wrong code increments `attempts` and commits; the right one sets the new hash, consumes the code and deletes every Sanctum token in one transaction |
| Answers | Forgot is always 202 `{status: requested}`; every reset failure is one 422 on `reset_token`. The mail goes out in `defer()` after the response; a failure logs only the exception class, never the address or code |
| Schema | CHECK on attempts 0 to 5 and on the hash shape; a partial unique index allows one open code per user; the foreign key restricts deletion, and the table is in the purge order |
| Limits | Both routes share the `password-reset` limiter: per IP and per email per hour. Emails are lower-cased the same way at register, forgot and reset |
| Legal | Brevo is named in `privacy.md` and `facts.json`; the version is 2026-10-25 and the register fixture and app pin follow it |

## 3. Findings

**L1 · Low · No ceiling on guessing over days**
The packet's "about 5 in a million" is the chance for one code. Because forgot and reset share the per-email hourly bucket, an attacker gets about four guesses an hour for one email, about 100 a day: roughly 1 in 10,000 a day, and about 0.3 % over a month of steady trying against one account. That is low, but it has no ceiling. Fix: count wrong tries per account over a rolling 24 hours; at 10, issue no new codes for that account until the 24 hours pass, with the same uniform 202. A Pest test and a mutant. The person can still sign in with their password if they remember it.

**I1 · Info · Someone can use up a person's reset requests**
The per-email bucket means a stranger who sends five requests an hour for your email keeps you from resetting in that hour. That is the price of the guessing limit, and a common one. No action; DEVICE_GATE does not need a step for it.

**I2 · Info · The known-email path does more work**
A live account opens a transaction and writes a row; an unknown email does not. The hash is the same on both paths, and the mail is sent after the response, so the difference is small database time. Accepted for v1.

**I3 · Info · A50 drops the user id from the HMAC**
Deviation 2. The lookup is scoped to the account and there is one open code per account, so a code from account A can never be checked against account B's row. Accepted.

## 4. Deviations

| # | Verdict |
|---|---|
| 1 `defer()` instead of `dispatchAfterResponse` | Accepted, and a good catch by its test |
| 2 HMAC with the app key only | Accepted (I3) |
| 3 `MAIL_FROM_ADDRESS` keeps `hello@example.com` | Accepted for dev and CI. The deployment phase sets the real sender, and its health check must refuse the placeholder outside local and testing |
| 4 `hosting_provider` "Render and Neon" | Name them separately: Render hosts the service, Neon stores the database. Do it in the deployment phase with the regions |
| 5 Privacy no longer mentions email verification | Accepted; the app does not verify email |
| 6 26's primary action is "Enter code" | Accepted (ASSUMPTION(A50-code)) |
| 7 Buttons follow the content on 25 and 27 | Accepted. Pinned buttons fight the keyboard on small phones |
| 8 `InfoCard.tintTitle` | Accepted |
| 9 The sign-in notice as an enum | Accepted |
| 10 A rejected password costs no try | Accepted |
| 11 ASSUMPTION tags A50-code and A48-phasing | Accepted |
| 12 Local only: the dev API restarted, screens.43c signed out on the emulator, one code issued and one wrong try for it | Accepted. Nothing is in a commit |

## 5. Open questions (answered)

1. **Legal facts before publishing.** Khay Studios fills `contact_email`, `postal_address` and `governing_law`. For the region: pick Frankfurt on both Render and Neon (the nearest region to Ghana on both); write it as "Render (Frankfurt, Germany)" for hosting and "Neon (Frankfurt, Germany)" for the database, named separately.
2. **A mail guard in the health check.** Yes. In the deployment phase, `/health` answers 503 outside local and testing when `MAIL_MAILER` is `log` or `array`, or the sender is still the `example.com` placeholder, so reset codes can never land in a log on a real host.

## 6. Risks to keep in view

- **Reset emails without a domain may land in spam.** The app already says "Check your spam folder" on screen 26 (as designed); tell your first testers the same. DEVICE_GATE step 86 checks it.
- **The device gate is unrun: steps 1 to 14 and 16 to 90 of `docs/DEVICE_GATE.md`.**
- **I could not verify CI for 6.2 or 6.4.**
- **A38 stands on your confirmation** that the pop-up reminder channel was your decision.
- **Dependabot has open branches.** Check CI and the generated diff before any merge.

## 7. Next steps

1. Put this file in `docs/reviews/`; the next prompt tells Claude Code to commit it unchanged as its first commit.
2. **Phase 6.6: deleting a habit, and swipe to archive or delete** (Khay Studios, 2026-10-25). The prompt follows in the reply.
3. **Storage for photos and exports:** Backblaze sign-up failed. Check whether Cloudflare R2 lets you create a bucket on your account (see the reply); the deployment phase depends on the answer.
4. **Run `docs/DEVICE_GATE.md`** on a real Android 13+ phone.
