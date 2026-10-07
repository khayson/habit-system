# Phase 0 gate on a running Android emulator: the real app calls /health and shows
# server_time, plus the A23 multi-isolate database test on the device.
# Needs: emulator running, API served (api-serve.ps1).
. "$PSScriptRoot\_env.ps1"

Push-Location $AppDir
try {
    flutter test integration_test/health_gate_test.dart integration_test/multi_isolate_db_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'device tests failed' }
} finally {
    Pop-Location
}
