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

## Checks

- `scripts\check.ps1` — everything CI runs: Pint, Larastan, Pest (real PostgreSQL), dart format,
  flutter analyze, flutter test.
- `scripts\app-gate.ps1` — device tests on a running emulator (Phase 0 gate + A23 spike).
- `scripts\mutation-check.ps1 [-RandomSeeds N]` — domain mutation check (every mutant must be
  killed) and an optional random-seed property run; both also run nightly in CI. Replay a
  failing seed with `$env:PROPERTY_SEEDS='N'`.

After changing drift tables: `dart run build_runner build` in `app\` (CI fails if generated code
is stale).

## Sync smoke run (not in CI)

Runs the real `SyncEngine`, `LocalMutationService` and `HttpSyncTransport` against the local API,
with two device databases (temp files) and two device tokens for one fresh account. Device A
creates a habit and ticks today; B bootstraps, sees both and unticks; A pulls. It prints each
sync outcome and outbox state, then `CONVERGED` (exit 0) or `DIVERGED` (exit 1).

```powershell
scripts\db-up.ps1
scripts\api-serve.ps1                     # in another terminal
cd app
dart run tool/sync_smoke.dart             # default http://127.0.0.1:8000/api/v1
dart run tool/sync_smoke.dart http://127.0.0.1:8000/api/v1
```

Each run registers a new `smoke+<ms>@example.test` account in the dev database.

## Known toolchain pins

- `analyzer` is pinned below 14.5 in `app/pubspec.yaml` (dev): `build_runner` 2.16.1 declares
  `analyzer <15` but does not compile against 14.5.0 (`contextFeatures` setter missing).
  **Remove the pin when** a `build_runner` release newer than 2.16.1 is out: delete the
  `analyzer` line, run `flutter pub upgrade build_runner` and `dart run build_runner build`.
  If generation succeeds, keep it removed; Dependabot will surface the release.
- Composer resolves as PHP 8.4.1 (`config.platform.php`, A24) even if your local PHP is newer.
