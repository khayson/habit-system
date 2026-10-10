# Development setup (Windows, Android first)

## What you need

| Tool | Version | Notes |
|---|---|---|
| PHP | 8.4 (NTS x64) | Native. `pdo_pgsql` **must** be enabled. |
| Composer | 2.x | |
| PostgreSQL | 16+ (CI uses 17) | Docker (preferred) or a portable install. |
| Flutter | 3.47.x stable (A24; CI pins 3.47.5) | Android SDK + an emulator AVD. |

iOS cannot be built on Windows (A17).

## PHP with pdo_pgsql

Laravel Herd Lite's PHP is a static build without `pdo_pgsql`, so it cannot run this API.
Use the official build from windows.php.net:

1. Download `php-8.4.x-nts-Win32-vs17-x64.zip` and unzip it, e.g. to `C:\Users\<you>\tools\php-8.4`.
2. Copy `php.ini-development` to `php.ini` and set:
   ```ini
   extension_dir = "ext"
   extension=curl
   extension=fileinfo
   extension=intl
   extension=mbstring
   extension=openssl
   extension=pdo_pgsql
   extension=pgsql
   extension=sodium
   extension=zip
   date.timezone = UTC
   memory_limit = 512M
   ```
3. Check: `php -m` lists `pdo_pgsql`.

The scripts use `php` from `PATH`; or set `$env:HABIT_PHP` to the full path of `php.exe`, and
`$env:HABIT_COMPOSER` to a `composer.phar` if Composer is not on `PATH`.

## PostgreSQL

**Docker (preferred):** `scripts\db-up.ps1` runs `docker compose up -d --wait postgres`. The
container creates `habit` and `habit_test` (user/password `habit`/`habit`, dev only).

> **Not yet run locally.** The dev machine has no Docker, so `docker-compose.yml` has only been
> checked with `docker compose config -q` (in CI). Treat the first real `up` as untested.

**Without Docker** (this dev machine has no Docker or WSL): use the EDB portable binaries.

```powershell
# once
Expand-Archive postgresql-17.x-windows-x64-binaries.zip C:\Users\<you>\tools
Rename-Item C:\Users\<you>\tools\pgsql pgsql-17
"habit" | Out-File -Encoding ascii $env:TEMP\pgpw
C:\Users\<you>\tools\pgsql-17\bin\initdb.exe -D C:\Users\<you>\tools\pgdata-17 -U habit --pwfile=$env:TEMP\pgpw -E UTF8 --locale=C -A scram-sha-256
Remove-Item $env:TEMP\pgpw

# each session
$env:HABIT_PG_BIN  = 'C:\Users\<you>\tools\pgsql-17\bin'
$env:HABIT_PG_DATA = 'C:\Users\<you>\tools\pgdata-17'
scripts\db-up.ps1
& "$env:HABIT_PG_BIN\psql.exe" -U habit -h 127.0.0.1 -d postgres -c "create database habit;" -c "create database habit_test;"   # once
```

## Run it

```powershell
scripts\db-up.ps1
scripts\api-setup.ps1     # first time
scripts\api-serve.ps1     # http://127.0.0.1:8000/api/v1/health
```

Start the Android emulator, then from `app\`:

```powershell
flutter run               # API_BASE_URL defaults to http://10.0.2.2:8000/api/v1
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Plain HTTP is allowed only in debug builds and only to `10.0.2.2` / `localhost`
(`android/app/src/debug/res/xml/network_security_config.xml`).

## Terms and Privacy pages (A33)

Screen 03 links to `<LEGAL_BASE_URL>/terms/` and `<LEGAL_BASE_URL>/privacy/`. The default base
is `https://khayson.github.io/habit-system`; a release build refuses anything but `https://`.

```powershell
flutter run --dart-define=LEGAL_BASE_URL=https://legal.example.com
```

Build the pages locally (from the repo root; draft documents and unfilled facts are warnings):

```powershell
php scripts\build-legal.php --out=$env:TEMP\legal
php scripts\build-legal.php --out=$env:TEMP\legal --publish   # fails until every fact is filled and both are final
```

Publishing to GitHub Pages (`.github/workflows/legal-pages.yml`):

1. Fill every `null` in `docs/legal/facts.json` and set `status: final` in both documents.
   When the wording changes, bump `version` in the document and in
   `app/lib/config/legal_config.dart` (`LegalVersions`) in the same commit (a test compares them).
2. Repository Settings → Pages → Source: **GitHub Actions** (once).
3. Actions → **Legal pages** → Run workflow, tick **publish**. Pull requests and pushes only
   build the pages as an artifact; they never deploy.

## Demo: two emulators converge (Phase 2b.2 gate)

Two Android emulators, one account. A creates a habit; B checks it in while A is offline; A
catches up when it reconnects.

```powershell
scripts\db-up.ps1
scripts\api-serve.ps1                    # leave running; emulators reach it at 10.0.2.2:8000
flutter emulators                        # needs two AVDs; create a second in Android Studio
flutter emulators --launch <avd-a>
flutter emulators --launch <avd-b>
flutter devices                          # note the ids, e.g. emulator-5554 and emulator-5556
cd app
flutter run -d emulator-5554             # terminal 1: device A
flutter run -d emulator-5556             # terminal 2: device B
```

1. **A**: Create account (12+ character password, tick the Terms line), then Continue on "Your
   day, your time". Today shows "Your first step". Tap **Create your first habit**, name it,
   then **Create habit**. Today lists it as "New · waiting to sync"; the chip moves from
   "1 waiting" to "Synced".
2. **B**: Sign in with the same email and password. A first sign-in on this device shows the
   timezone screen; Continue. Today shows the habit once the first sync finishes.
3. Take **A** offline:
   `adb -s emulator-5554 shell cmd connectivity airplane-mode enable`.
   A keeps working: check in and undo freely; the chip says "Offline" and the sync screen
   (tap the chip) lists the queued changes. Leave the habit unchecked on A.
4. **B**: tap the habit. It shows "Done · waiting to sync", then "Done" with the chip at
   "Synced".
5. Bring **A** back:
   `adb -s emulator-5554 shell cmd connectivity airplane-mode disable`.
   Regaining a connection triggers a sync at once: A shows "Done" and "Synced". Both devices
   now hold the same confirmed state.

If A had checked in offline too, both changes would land on the same habit-day: the server
keeps one log and A's change is remapped to it (the e2e "merged" scenario). Pull-to-refresh is
not needed: start, resume, every local write and connectivity changes all trigger a sync, and
the sync screen has **Sync now**.

## Checks

- `scripts\check.ps1` — everything CI runs: Pint, Larastan, Pest (real PostgreSQL), dart format,
  flutter analyze, flutter test.
- `scripts\app-gate.ps1` — device tests on a running emulator (Phase 0 gate + A23 spike).
- `scripts\mutation-check.ps1 [-RandomSeeds N]` — domain mutation check (every mutant must be
  killed) and an optional random-seed property run; both also run nightly in CI. Replay a
  failing seed with `$env:PROPERTY_SEEDS='N'`.

After changing drift tables: `dart run build_runner build` in `app\` (CI fails if generated code
is stale).

## Sync end-to-end run (CI job `e2e`)

Runs the real `SyncEngine`, `LocalMutationService` and `HttpSyncTransport` against a running API,
with two device databases (temp files) and two device tokens for one fresh account. Scenarios:
setup (create a habit on A, bootstrap B), merged (both tick the same day offline; B is remapped
to A's log id), conflict (a stale edit is kept as needs-attention, then discarded), restore (A
deletes, B logs again on the tombstone version), db-restore (the server journal rolls back: 410,
re-bootstrap, the queued edit survives) and refresh (the old token works inside the 10-minute
grace window) and derived (a past day closes and the other device receives `habit_progress` and
`period_evaluation`, A32). It prints PASS/FAIL per scenario, then `CONVERGED` (exit 0) or stops non-zero.

```powershell
scripts\db-up.ps1
scripts\api-serve.ps1                     # in another terminal
cd app
$env:E2E_DATABASE_URL = 'postgresql://habit:habit@127.0.0.1:5432/habit'
$env:E2E_PSQL = "$env:USERPROFILE\tools\pgsql-17\bin\psql.exe"   # if psql is not on PATH
$env:E2E_CLOSE_CMD = "$env:USERPROFILE\tools\php-8.4\php.exe ..\api\artisan habits:close-periods --sync"
dart run tool/sync_e2e.dart               # default http://127.0.0.1:8000/api/v1
```

The db-restore scenario edits the dev database directly (it rolls back that test account's
journal), so point `E2E_DATABASE_URL` at a development database only. Each run registers a new
`e2e+<ms>@example.test` account.

## Known toolchain pins

- `analyzer` is pinned below 14.5 in `app/pubspec.yaml` (dev): `build_runner` 2.16.1 declares
  `analyzer <15` but does not compile against 14.5.0 (`contextFeatures` setter missing).
  **Remove the pin when** a `build_runner` release newer than 2.16.1 is out: delete the
  `analyzer` line, run `flutter pub upgrade build_runner` and `dart run build_runner build`.
  If generation succeeds, keep it removed; Dependabot will surface the release.
- Composer resolves as PHP 8.4.1 (`config.platform.php`, A24) even if your local PHP is newer.
