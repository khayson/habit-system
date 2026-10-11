# Serves the API at http://127.0.0.1:8000 (the Android emulator reaches it as 10.0.2.2:8000).
# -E2E lifts the per-user sync limit for the sync end-to-end run (one account, every scenario).
param([switch]$E2E)
. "$PSScriptRoot\_env.ps1"

if ($E2E) { $env:RATE_LIMIT_SYNC_PER_MINUTE = '600' }

Push-Location $ApiDir
try {
    Invoke-Php artisan serve --host=127.0.0.1 --port=8000
} finally {
    Pop-Location
}
