# Runs the same checks as CI, locally. Needs PostgreSQL up (db-up.ps1).
. "$PSScriptRoot\_env.ps1"

Push-Location $ApiDir
try {
    Invoke-Php vendor/bin/pint --test
    Invoke-Php vendor/bin/phpstan analyse --memory-limit=1G --no-progress
    Invoke-Php vendor/bin/pest
} finally {
    Pop-Location
}

Push-Location $AppDir
try {
    flutter pub get
    # Generated *.g.dart is build_runner's output (80 columns); CI checks it is up to date instead.
    $sources = Get-ChildItem lib, test, integration_test, tool -Recurse -Filter *.dart |
        Where-Object { $_.Name -notlike '*.g.dart' } | ForEach-Object { $_.FullName }
    dart format --output=none --set-exit-if-changed @sources
    if ($LASTEXITCODE -ne 0) { throw 'dart format found changes' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
} finally {
    Pop-Location
}
Write-Host 'All checks passed.'
