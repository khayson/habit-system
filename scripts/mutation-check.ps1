# Runs the domain mutation check (api/tests/Mutation). Every mutant must make the suite fail.
# Optional: -RandomSeeds N also runs the property tests with N random seeds.
param([int]$RandomSeeds = 0)
. "$PSScriptRoot\_env.ps1"

Push-Location $ApiDir
try {
    if ($RandomSeeds -gt 0) {
        $env:PROPERTY_RANDOM_SEEDS = "$RandomSeeds"
        try { Invoke-Php vendor/bin/pest tests/Unit/Domain/PropertiesTest.php }
        finally { Remove-Item Env:PROPERTY_RANDOM_SEEDS -ErrorAction SilentlyContinue }
    }
    Invoke-Php tests/Mutation/run.php
} finally {
    Pop-Location
}
