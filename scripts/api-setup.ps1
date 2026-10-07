# First-time API setup: dependencies, .env, app key, migrations.
. "$PSScriptRoot\_env.ps1"

$modules = & $Php -m
if ($modules -notcontains 'pdo_pgsql') {
    throw "pdo_pgsql is not enabled for '$Php'. Enable extension=pdo_pgsql in php.ini (docs/DEV_SETUP.md)."
}

Push-Location $ApiDir
try {
    Invoke-Composer install --no-interaction
    if (-not (Test-Path '.env')) {
        Copy-Item '.env.example' '.env'
        Invoke-Php artisan key:generate
    }
    Invoke-Php artisan migrate --force
} finally {
    Pop-Location
}
