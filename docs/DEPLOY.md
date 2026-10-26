# Deploying Habit System (A54)

This guide is for Khay Studios. It takes you from nothing to a live server and an APK on your phone. Every account, dashboard click and secret is yours: Claude Code prepared the repository but never logs in anywhere.

**Keep every secret to yourself.** Passwords, keys, tokens and connection strings go only into the dashboard field this guide names, or into your password manager. Never paste one into a chat, an issue, a commit or a file in this repository.

You will need about two hours the first time. Do the steps in order; each one ends with a check.

| What | Where | Cost |
|---|---|---|
| Database | Neon, Frankfurt | free |
| Photos and exports | Cloudflare R2, bucket `habit-files` (done) | free |
| Email | Brevo | free (300 emails a day) |
| Server | Render free web service, Frankfurt (New Web Service form, as for the movies app) | free |
| Timer | cron-job.org | free |
| App download | GitHub Releases and GitHub Pages | free |

Keep a note open as you go (in your password manager, not a text file) with these names, filled in as you reach them:

```
DB_URL                 (step 1)
R2_ENDPOINT            (step 2)
R2_ACCESS_KEY_ID       (step 2)
R2_SECRET_ACCESS_KEY   (step 2)
MAIL_USERNAME          (step 3)
MAIL_PASSWORD          (step 3)
MAIL_FROM_ADDRESS      (step 3)
APP_KEY                (step 4)
TICK_SECRET            (step 4)
EXPORT_SIGNING_KEYS    (step 4)
APP_URL                (step 5)
keystore passwords     (step 7)
```

---

## 1. Neon: the database

1. Go to https://neon.tech and sign up (GitHub sign-in is fine).
2. **Create project**:
   - Name: `habit`.
   - Postgres version: the newest offered (16 or later).
   - Region: **AWS Europe Central 1 (Frankfurt)**.
3. On the project dashboard click **Connect**.
   - Database: `neondb`; role: the default owner.
   - **Turn "Connection pooling" off.** The host must not contain `-pooler`. The API needs a direct connection: it relies on row locks that a pooler can break between statements.
   - Copy the connection string. It looks like `postgresql://neondb_owner:…@ep-something-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require`.
   - If it ends with `&channel_binding=require` as well, keep that.
4. Save it as **DB_URL**.

Check: the string starts with `postgresql://`, contains `eu-central-1`, has no `-pooler`, and contains `sslmode=require`.

## 2. Cloudflare R2: the API token for `habit-files`

The bucket exists and public access is off. Leave it that way: the app never needs public access.

1. In the Cloudflare dashboard open **R2 Object Storage**.
2. On the R2 overview page, click **Manage API tokens** (or **API**, then **Manage API Tokens**), then **Create API token** (an R2 token, not an account-wide token).
3. Fill in:
   - Token name: `habit-api`.
   - Permissions: **Object Read & Write**.
   - Specify bucket(s): **Apply to specific buckets only**, then pick `habit-files`.
   - TTL: forever (or a long date you will remember to renew).
4. Click **Create API Token**. The next page shows its values **once**:
   - **Access Key ID**: save as **R2_ACCESS_KEY_ID**.
   - **Secret Access Key**: save as **R2_SECRET_ACCESS_KEY**.
   - The S3 endpoint for your account, `https://<account id>.r2.cloudflarestorage.com`: save as **R2_ENDPOINT**.
   - If the bucket's settings page shows an S3 API URL ending in `/habit-files`, leave that last part off. If your bucket shows an `.eu.` endpoint, use that one.
5. While you are in Cloudflare, open your other bucket, `schoolbookapp`, then **Settings** and **Public Development URL**. If it is enabled and that app does not need it, disable it.

Check: R2_ENDPOINT starts with `https://`, ends in `r2.cloudflarestorage.com`, and has no bucket name at the end.

## 3. Brevo: email

1. Go to https://www.brevo.com and sign up (free plan).
2. **Add a sender:**
   - Click your name (top right), then **Senders, domains & dedicated IPs**, then **Senders**, then **Add a sender**.
   - Use an address you read, for example your Gmail address. Brevo sends a code to it; enter the code to verify the sender.
   - Save the address as **MAIL_FROM_ADDRESS**.
   - Without your own domain, some reset emails will land in spam. The download page tells testers to look there.
3. **Get the SMTP login and key:**
   - Click your name, then **SMTP & API**, then the **SMTP** tab.
   - Copy the **Login** (it looks like `8a1b2c003@smtp-brevo.com`) and save it as **MAIL_USERNAME**.
   - Click **Generate a new SMTP key** and name it `habit-api`. Copy the key at once and save it as **MAIL_PASSWORD**. This is the SMTP key, not an API key.

Check: MAIL_FROM_ADDRESS shows as **Verified** in Brevo.

## 4. Generate APP_KEY, TICK_SECRET and the export signing key

Run this once in **PowerShell** on your computer. It prints three lines; copy each value into your password manager, then close the window.

```powershell
function New-Secret([int]$bytes) { $b = New-Object byte[] $bytes; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); $b }
'APP_KEY=base64:' + [Convert]::ToBase64String((New-Secret 32))
'TICK_SECRET=' + (-join ((New-Secret 32) | ForEach-Object { $_.ToString('x2') }))
'EXPORT_SIGNING_KEYS=prod-1:' + (-join ((New-Secret 32) | ForEach-Object { $_.ToString('x2') }))
'OPS_SECRET=' + (-join ((New-Secret 32) | ForEach-Object { $_.ToString('x2') }))
```

- **APP_KEY** includes the `base64:` prefix.
- **TICK_SECRET** is 64 hex characters.
- **EXPORT_SIGNING_KEYS** is the whole `prod-1:…` value. `prod-1` is the key's name; Render already sets `EXPORT_SIGNING_KID=prod-1`.

Never reuse these elsewhere, and never change APP_KEY after the first deploy: it would sign everyone out.

## 5. Render: the server

This is the same **New Web Service** form you used for the movies app. `render.yaml` in the repository lists the same settings, for reference only.

1. In Render: **Projects**, then **habit-system**, then **Production**, then **New**, then **Web Service**. Pick the repository `khayson/habit-system`.
2. Fill the form:

   | Field | Value |
   |---|---|
   | Name | `habit-system` (your address becomes `https://habit-system.onrender.com`, or with a suffix if the name is taken) |
   | Project / Environment | habit-system / Production |
   | Language | **Docker** |
   | Branch | `main` |
   | Region | **Frankfurt (EU Central)**, not Oregon. The database is in Frankfurt, and every request talks to it. |
   | Root Directory | `api` |
   | Dockerfile Path | `./Dockerfile` (relative to the root directory, so it means `api/Dockerfile`) |
   | Instance type | **Free** ($0, 0.1 CPU, 512 MB) |

3. **Environment Variables**: click **Add from .env** and paste the block below. First replace each `<…>` with the value from your password manager, in the paste box only. Never save the filled block in a file.

   ```
   APP_NAME="Habit System"
   APP_ENV=production
   APP_DEBUG=false
   APP_KEY=<APP_KEY from step 4>
   APP_URL=https://habit-system.onrender.com
   LOG_CHANNEL=stderr
   LOG_LEVEL=warning
   TRUSTED_PROXIES=*
   DB_CONNECTION=pgsql
   DB_URL=<DB_URL from step 1>
   CACHE_STORE=database
   QUEUE_CONNECTION=database
   SESSION_DRIVER=array
   AVATAR_DISK=r2
   EXPORT_DISK=r2
   R2_BUCKET=habit-files
   R2_ENDPOINT=<R2_ENDPOINT from step 2>
   R2_ACCESS_KEY_ID=<R2_ACCESS_KEY_ID from step 2>
   R2_SECRET_ACCESS_KEY=<R2_SECRET_ACCESS_KEY from step 2>
   MAIL_MAILER=smtp
   MAIL_SCHEME=smtp
   MAIL_HOST=smtp-relay.brevo.com
   MAIL_PORT=2525
   MAIL_USERNAME=<MAIL_USERNAME from step 3>
   MAIL_PASSWORD=<MAIL_PASSWORD from step 3>
   MAIL_FROM_ADDRESS=<MAIL_FROM_ADDRESS from step 3>
   MAIL_FROM_NAME="Habit System"
   EXPORT_SIGNING_KEYS=<EXPORT_SIGNING_KEYS from step 4>
   EXPORT_SIGNING_KID=prod-1
   TICK_SECRET=<TICK_SECRET from step 4>
   TICK_MAX_SECONDS=25
   MIN_APP_VERSION=1
   OPS_SECRET=<OPS_SECRET from step 4>
   ```

   Do not add `PORT`: Render sets it and the image listens on it.
4. Open **Advanced**:
   - **Health Check Path:** `/api/v1/health`.
   - **Auto-Deploy:** On Commit.
   - Leave the Docker Command empty (the image starts itself), and add no disk.
5. Click **Deploy web service**. The first build takes about 5 to 10 minutes. Watch **Logs**: the image builds, then the start script caches config and runs the migrations, and nginx starts. The database already has its tables (they were created from this computer on 2026-10-26), so the migrations report nothing to do.
6. When the service shows **Live**, open `https://<your service>.onrender.com/api/v1/health` in a browser. It should show `"status":"ok"` and `"min_app_version":1`.
7. **If the address differs** from `https://habit-system.onrender.com`: open the service, then **Environment**, set **APP_URL** to the real address, and save. Render redeploys. Use the real address everywhere below.
8. **Free hours are shared by the workspace.** Render gives 750 free instance hours a month for all free services together. The movies service in Oregon counts too. Two services kept awake all month need about 1,490 hours, so the free hours would run out around day 25 and both would stop until the next month. Choose one:
   - let the movies service sleep when idle (no timer keeping it awake);
   - move one of them to its own Render workspace;
   - accept that habit-system pauses near the end of a month.

Check: `/api/v1/health` shows ok. If it shows `unavailable`, see step 10.

## 6. cron-job.org: the timer

Render's free service has no cron and goes to sleep after about 15 idle minutes. One job every 5 minutes runs the scheduled work and the queue, and keeps the server awake.

1. Go to https://cron-job.org and sign up (free).
2. **Create cronjob**:
   - Title: `habit tick`.
   - URL: `https://<your service>.onrender.com/api/v1/internal/tick`.
   - Execution schedule: **Every 5 minutes**.
3. Open the **Advanced** tab:
   - Request method: **POST**.
   - Headers: add one header. Key `X-Tick-Secret`, value: TICK_SECRET.
   - Timeout: the longest offered (30 seconds on the free plan). The server stops its work before that.
   - Treat redirects as failure: on.
4. Save, then click **Test run**. The answer should be **204 No Content**.
   - A **404** means the secret or the URL is wrong.
   - A timeout on the first run is normal while the server wakes up. Run it again.
5. Optional second job: `GET https://<your service>.onrender.com/api/v1/health` every 30 minutes, with **Notify me on failure** on, so you hear about an outage.

Check: after 15 minutes, the job's history shows 204s.

## 7. Your Android signing key

The APK must be signed with your own key. Every update must use the same key, or it will not install over the app already on a phone. **If you lose this key or its password, you can never ship an update to that app again.** Testers would have to uninstall, losing their phone's local data.

1. Make a folder outside the repository, for example `C:\Users\<you>\keys`.
2. In PowerShell:

   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v `
     -keystore "$env:USERPROFILE\keys\habit-release.jks" -storetype JKS `
     -keyalg RSA -keysize 4096 -validity 10000 -alias habit
   ```

   It asks for a keystore password (choose a long one), your name and organisation, and the key password (use the same one, or another long one).
3. Copy `app\android\key.properties.example` to `app\android\key.properties` (this file is git-ignored) and fill it in:

   ```
   storeFile=C:/Users/<you>/keys/habit-release.jks
   storePassword=<keystore password>
   keyAlias=habit
   keyPassword=<key password>
   ```

4. **Back it up now:** put `habit-release.jks` and both passwords in your password manager, and put a copy of the `.jks` on a USB stick kept somewhere safe. Never commit it, email it or upload it to GitHub.

Check: `git status` in the repository shows neither `key.properties` nor the `.jks`.

## 8. Build the APK and publish it

1. In PowerShell, from the repository folder:

   ```powershell
   scripts\release-apk.ps1 -ApiBaseUrl https://<your service>.onrender.com/api/v1
   ```

   It builds two APKs and prints each one's path, size and SHA-256. A missing `key.properties` stops it with a clear message.
2. On GitHub, open the repository, then **Releases**, then **Draft a new release**:
   - Tag: `v1.0.0` (create it on `main`). Title: `Habit System 1.0.0`.
   - Upload `app-arm64-v8a-release.apk` and `app-armeabi-v7a-release.apk` from the printed paths. Keep these file names: the download page links to them.
   - Paste the two SHA-256 lines into the description.
   - **Publish release**.
3. Put the two SHA-256 values into `docs/legal/download.json`, replacing the two `null`s, and commit. On GitHub you can edit the file in the browser.
4. Turn on GitHub Pages once: **Settings**, then **Pages**, then **Source: GitHub Actions**.
5. Publish the pages:
   - Open **Actions**, then **Legal pages**, then **Run workflow** on `main`.
   - Tick **publish_draft** (the Terms and Privacy pages say they are drafts until you fill in `contact_email`, `postal_address` and `governing_law` in `docs/legal/facts.json`, and set both documents to `status: final`), then run.
   - Once those facts are filled and the texts reviewed, use **publish** instead.
6. Open `https://khayson.github.io/habit-system/download/` on your phone, tap **Download for Android**, and install (allow "install unknown apps" when asked).

Check: the app opens, you can create an account, and Today shows. Then run the device gate (`docs/DEVICE_GATE.md`) against this server.

## 9. Smoke test

From the repository folder, with an address you own (a reset email is sent to it; a `+` tag keeps it apart):

```powershell
scripts\smoke.ps1 -BaseUrl https://<your service>.onrender.com -Email you+smoke1@gmail.com -TickSecret <TICK_SECRET>
```

It checks health, registers a throwaway account, syncs a habit, makes an export through the queue and R2 and downloads it, asks for a reset code, then deletes the account.

- Every line should say **OK**. It never prints the password or the secret.
- A reset email from your Brevo sender should arrive (look in spam too).
- Use a new `+` tag each time.
- Leaving out `-TickSecret` waits for cron-job.org instead (up to 7 minutes).

## 9b. Checking the system's health (A55)

A read-only status in numbers only:
- accounts, and deletions pending;
- check-ins in the last 24 hours;
- jobs waiting and failed;
- when the timer last ran;
- reset-email failures in the last 7 days;
- how full the database is.

It shows no names, emails or habits. Run this in your own PowerShell window (it needs `OPS_SECRET`, not the tick secret):

```powershell
(Invoke-RestMethod -Uri https://<your service>.onrender.com/api/v1/internal/status -Headers @{ 'X-Ops-Secret' = '<OPS_SECRET>' }).data | ConvertTo-Json -Depth 3
```

What to look for:
- `last_tick_at` within the last 5 to 10 minutes;
- `queue.failed` at 0, and `queue.oldest_waiting_seconds` under about 600;
- `mail_failures.last_7_days` at 0;
- `database.used_percent` well under 80.

Without the secret the address answers a plain 404. On a machine with the API, `php artisan ops:status` prints the same numbers.

If you added the service before this step existed: generate `OPS_SECRET` (step 4), add it under Render, **Environment**, then **Save and deploy**.

## 9c. Publishing a notice on Today (A57)

A notice is a short plain-text card in everyone's Today carousel: a title of up to 60 characters and a body of up to 280. It has no links or images. Keep it calm, with no pressure or loss wording.

Open the service in Render, then **Shell**, and run:

```sh
php artisan notices:publish --title="Weekly habits are here" --body="A habit can now count the days you choose each week." --ends=2026-11-15T00:00:00Z
php artisan notices:publish --title="Thanks for the report" --body="The fix is in the next update." --to=maya@example.com --to=kofi@example.com
php artisan notices:list
php artisan notices:retire <id>
```

- `--starts` and `--ends` are optional ISO-8601 times with a zone. Without `--starts`, the notice starts now.
- `--to` sends it only to those accounts; repeat it for more people. An email with no account stops the publish. Without `--to`, everyone sees it.
- The app shows at most 5 at once, newest first, and refreshes them at most every 15 minutes.
- Each person can dismiss a notice on their phone.
- `notices:retire` ends a notice now. One that has not started yet is removed.

## 10. When something fails

**Where to look first:** Render, then **habit-api**, then **Logs**. The server logs warnings and errors only, never passwords, tokens or emails.

**`/health` says `unavailable`.** The log says why, at the moment of the health check:

| Log line | Meaning | Fix |
|---|---|---|
| `mail not deliverable` with `mailer_log` or `mailer_array` | MAIL_MAILER is not `smtp` | Set it back to `smtp` (Environment) |
| `mail not deliverable` with `sender` | MAIL_FROM_ADDRESS is empty or a placeholder | Set your verified Brevo sender |
| `database not answering` | DB_URL is wrong, or Neon is down | Check the string from step 1 (direct, `sslmode=require`) |
| `export signing key unusable` | EXPORT_SIGNING_KEYS is the test key or shorter than 32 characters | Generate it again (step 4) |

**The deploy fails at start.**
- `could not translate host name` or `password authentication failed`: DB_URL is wrong.
- `No application encryption key`: APP_KEY is missing.

**The tick does not run.**
- cron-job.org shows 404: the URL or the `X-Tick-Secret` header is wrong.
- It shows timeouts all the time: the service may be failing its health check; look at the Render logs.
- Exports and account deletions wait until the next tick (up to 5 minutes), so that much delay is normal.

**`reset email failed` with `TransportException` in the log.** The server cannot talk to Brevo. Render's free tier blocks the SMTP ports 25, 465 and 587, so `MAIL_PORT` must be **2525**. If it is 2525 and this still happens, check `MAIL_USERNAME` (the SMTP login, `…@smtp-brevo.com`) and `MAIL_PASSWORD` (an SMTP key, not an API key).

**Mail lands in spam.** Expected without your own domain. Ask testers to mark it "not spam". A domain with SPF and DKIM set up in Brevo fixes it later.

**Photo upload or export fails.**
- The log shows `avatar object delete failed` or `export failed`.
- Check R2_ENDPOINT (no bucket name at the end), the token's bucket (`habit-files`), and that it has Object Read & Write.

**The app says "A new version is ready".** The server's MIN_APP_VERSION is above the app's build number. Install the latest APK from the download page. Raise MIN_APP_VERSION only after publishing a release with a higher build number.

**Rolling back.** Render, then **habit-api**, then **Events**: choose an earlier deploy, then **Rollback**. Migrations are not undone by a rollback, so a release with a migration needs care.
