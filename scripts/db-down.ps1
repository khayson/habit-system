# Stops PostgreSQL started by db-up.ps1. Data is kept.
. "$PSScriptRoot\_env.ps1"

if (Test-DockerAvailable) {
    docker compose -f (Join-Path $RepoRoot 'docker-compose.yml') stop postgres
    return
}
if ($PgBin -and $PgData) {
    & (Join-Path $PgBin 'pg_ctl.exe') stop -D $PgData -m fast
}
