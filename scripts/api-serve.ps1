# Serves the API at http://127.0.0.1:8000 (the Android emulator reaches it as 10.0.2.2:8000).
. "$PSScriptRoot\_env.ps1"

Push-Location $ApiDir
try {
    Invoke-Php artisan serve --host=127.0.0.1 --port=8000
} finally {
    Pop-Location
}
