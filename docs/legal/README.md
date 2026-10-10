# Legal documents

`terms.md` and `privacy.md` are the source of the public Terms of Service and Privacy Policy pages. `facts.json` holds the facts the texts refer to as `{{name}}`. Only Khay Studios and the architect edit these files; Claude Code builds the pages from them and never changes their wording.

## How it works

- Front matter: `title`, `version` (the revision date, `YYYY-MM-DD`), `effective` (the date it takes effect, `YYYY-MM-DD`) and `status` (`draft` or `final`).
- `{{name}}` is replaced from `facts.json`. A fact that is `null` blocks publishing. `status: draft` blocks publishing too. Both are fine while building and testing.
- The app records the `version` of each document the user accepted when they create an account. The app's own copy of the versions is pinned to these files by a test, so a text change forces a conscious version bump.

## Rules

1. Any change that collects new data, adds a third party, or changes how long data is kept updates these files in the same commit and bumps the `version`.
2. A wording change after publication also bumps the `version`. A material change also needs a re-consent flow (not built yet; Phase 7).
3. Git history is the archive of past versions.

## Claims that must stay true

The Privacy Policy and Terms make these claims. Each one maps to something the product does. Check the whole table before every release and whenever a feature touches it.

| Claim | Where it comes from | If it stops being true |
|---|---|---|
| Passwords are stored only as a hash, and never returned or exported | Spec `users.password` | Update privacy §2 and §9 |
| New passwords are checked against Have I Been Pwned with a 5-character hash prefix | A16, `auth.password_breach_check` on in production | Update privacy §5 |
| No ads and no third-party analytics or crash-reporting SDK in the app | `app/pubspec.yaml`, `api/composer.json` | Update privacy summary, §2, §5 |
| Servers send no push notifications; reminders are scheduled on the device | A7 and the reminder-device endpoints are not built | Update privacy §3, §5 |
| No marketing emails | Product decision | Update privacy §2 |
| Location is a typed or picked "City, Country" label, never GPS | A20 | Update privacy §2 |
| Photos: metadata removed, re-encoded, original discarded, private storage, no public URL | A20 | Update privacy §7, §9 |
| Account purge within 30 days, backups age out within 90 days, export link 24 hours | Limits table in the amendments | Update privacy §7 |
| Deletion records kept up to 180 days | Journal retention in the amendments | Update privacy §7 |
| Technical logs kept `log_retention_days` days | Server logging setup (Phase 7) | Update the fact and privacy §7 |
| Data is hosted with `hosting_provider` in `hosting_region` | Deployment (Phase 7) | Update the facts and privacy §5, §6 |
| Reminder text includes the habit name | Phase 3.2b | If a "hide habit names" setting ships, update privacy §3 |
| The app does not encrypt its on-device database | Phase 7 carry | If it does, update privacy §6 |
| No public profiles and no sharing with other users | Spec privacy default | Update the summary and §1 |

## Before each release

1. Every fact in `facts.json` is filled in and true.
2. A lawyer has reviewed both texts and `status` is `final`.
3. `effective` is the release date.
4. The claims table above has been checked against the code.
5. The store privacy forms (Google Play Data safety, App Store privacy details) match the Privacy Policy.
6. The pages are published and the app's links open them.
