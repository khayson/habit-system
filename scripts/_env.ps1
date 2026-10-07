# Shared settings for the helper scripts. Dot-source it: . "$PSScriptRoot\_env.ps1"
# Works in Windows PowerShell 5.1 and PowerShell 7 (pwsh).
# Override any path with an environment variable before running a script.

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ApiDir = Join-Path $RepoRoot 'api'
$AppDir = Join-Path $RepoRoot 'app'

# PHP 8.4 with pdo_pgsql enabled in its php.ini. Defaults to `php` on PATH.
$Php = if ($env:HABIT_PHP) { $env:HABIT_PHP } else { 'php' }
# Composer: a composer.phar path, or `composer` on PATH.
$Composer = $env:HABIT_COMPOSER

# Portable PostgreSQL (used only when Docker is not available).
$PgBin = $env:HABIT_PG_BIN
$PgData = $env:HABIT_PG_DATA

function Invoke-Php {
    & $Php @args
    if ($LASTEXITCODE -ne 0) { throw "php $($args -join ' ') failed ($LASTEXITCODE)" }
}

function Invoke-Composer {
    if ($Composer) { Invoke-Php $Composer @args } else {
        & composer @args
        if ($LASTEXITCODE -ne 0) { throw "composer failed ($LASTEXITCODE)" }
    }
}

function Test-DockerAvailable {
    return [bool](Get-Command docker -ErrorAction SilentlyContinue)
}
