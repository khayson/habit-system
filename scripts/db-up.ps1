# Starts PostgreSQL: Docker Compose when available, otherwise a portable install
# (HABIT_PG_BIN + HABIT_PG_DATA, see docs/DEV_SETUP.md).
. "$PSScriptRoot\_env.ps1"

if (Test-DockerAvailable) {
    docker compose -f (Join-Path $RepoRoot 'docker-compose.yml') up -d --wait postgres
    if ($LASTEXITCODE -ne 0) { throw 'docker compose failed' }
    Write-Host 'PostgreSQL (Docker) is up on 127.0.0.1:5432.'
    return
}

if (-not $PgBin -or -not $PgData) {
    throw 'Docker not found. Set HABIT_PG_BIN and HABIT_PG_DATA for a portable PostgreSQL (docs/DEV_SETUP.md).'
}

& (Join-Path $PgBin 'pg_ctl.exe') status -D $PgData | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host 'PostgreSQL (portable) is already running.'
    return
}
& (Join-Path $PgBin 'pg_ctl.exe') start -D $PgData -l (Join-Path $PgData 'server.log') -o '-p 5432' -w
if ($LASTEXITCODE -ne 0) { throw 'pg_ctl start failed' }
Write-Host 'PostgreSQL (portable) is up on 127.0.0.1:5432.'
