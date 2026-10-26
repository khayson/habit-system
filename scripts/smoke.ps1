# A54: a smoke test against a live API (docs\DEPLOY.md step 9).
#   scripts\smoke.ps1 -BaseUrl https://<service>.onrender.com -Email you+smoke1@gmail.com [-TickSecret <secret>]
# Registers a throwaway account with -Email (use an address you own: a reset email is sent to
# it), syncs one habit, requests a JSON export and downloads it, requests a reset code, and
# deletes the account. With -TickSecret it runs the tick itself instead of waiting for
# cron-job.org. Prints each step's result; never the password, the token or the secret.
param(
    [Parameter(Mandatory = $true)][string]$BaseUrl,
    [Parameter(Mandatory = $true)][string]$Email,
    [string]$TickSecret = '',
    [int]$ExportWaitSeconds = 420
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_env.ps1"

$api = $BaseUrl.TrimEnd('/') + '/api/v1'
$script:failed = $false

function Step([string]$name, [scriptblock]$body) {
    try {
        $note = & $body
        Write-Output ("OK    {0}{1}" -f $name, $(if ($note) { " ($note)" } else { '' }))
    } catch {
        $script:failed = $true
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        Write-Output ("FAIL  {0}: {1}" -f $name, $(if ($status) { "HTTP $status" } else { $_.Exception.Message }))
        throw
    }
}

function New-Uuid7 {
    $ms = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $b = New-Object byte[] 16
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    for ($i = 0; $i -lt 6; $i++) { $b[$i] = [byte](($ms -shr (8 * (5 - $i))) -band 0xff) }
    $b[6] = [byte](($b[6] -band 0x0f) -bor 0x70)
    $b[8] = [byte](($b[8] -band 0x3f) -bor 0x80)
    $h = ($b | ForEach-Object { $_.ToString('x2') }) -join ''
    '{0}-{1}-{2}-{3}-{4}' -f $h.Substring(0, 8), $h.Substring(8, 4), $h.Substring(12, 4), $h.Substring(16, 4), $h.Substring(20)
}

function Version([string]$file) {
    (Select-String -Path (Join-Path $RepoRoot "docs\legal\$file") -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
}

function Call([string]$method, [string]$path, $body = $null, [hashtable]$headers = @{}) {
    $request = @{ Method = $method; Uri = "$api$path"; Headers = $headers + @{ Accept = 'application/json' }; ContentType = 'application/json' }
    if ($null -ne $body) { $request.Body = ($body | ConvertTo-Json -Depth 10 -Compress) }
    Invoke-RestMethod @request
}

$password = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
$deviceId = New-Uuid7
$auth = @{}

try {
    Step 'health' {
        $h = Call GET '/health'
        if ($h.data.status -ne 'ok') { throw "status $($h.data.status)" }
        "min_app_version $($h.meta.min_app_version)"
    }
    Step 'register a throwaway account' {
        $r = Call POST '/auth/register' @{
            name = 'Smoke test'; email = $Email; password = $password; timezone = 'Europe/Berlin'
            device_name = 'smoke.ps1'; device_id = $deviceId
            terms_version = (Version 'terms.md'); privacy_version = (Version 'privacy.md')
        }
        $auth.Authorization = 'Bearer ' + $r.data.token
        'account created'
    }
    Step 'sync one habit' {
        $habit = New-Uuid7
        $mutation = New-Uuid7
        $s = Call POST '/sync' @{
            device_id = $deviceId
            mutations = @(@{
                mutation_id = $mutation; entity = 'habit'; entity_id = $habit; operation = 'habit.create'
                base_version = $null; occurred_at = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
                captured_timezone = 'Europe/Berlin'
                payload = @{
                    name = 'Smoke'; type = 'binary'; target_value = 1; unit = $null; category = 'other'
                    frequency_type = 'daily'; frequency_config = @{}; start_local_date = (Get-Date).ToString('yyyy-MM-dd')
                    icon = 'star'
                }
            })
        } @{ Authorization = $auth.Authorization; 'Idempotency-Key' = $mutation }
        $ack = $s.data.acks[0]
        if ($ack.status -ne 'accepted') { throw "ack $($ack.status)" }
        'accepted'
    }
    Step 'export (JSON) through the queue and the file store' {
        $job = Call POST '/exports' @{ format = 'json' } @{ Authorization = $auth.Authorization }
        $id = $job.data.id
        $deadline = (Get-Date).AddSeconds($ExportWaitSeconds)
        do {
            if ($TickSecret) {
                try { Invoke-WebRequest -UseBasicParsing -Method POST -Uri "$api/internal/tick" -Headers @{ 'X-Tick-Secret' = $TickSecret } | Out-Null } catch { }
            } else { Start-Sleep -Seconds 15 }
            $job = Call GET "/exports/$id" $null @{ Authorization = $auth.Authorization }
        } while ($job.data.status -in @('queued', 'running') -and (Get-Date) -lt $deadline)
        if ($job.data.status -ne 'ready') { throw "export status $($job.data.status)" }
        $file = [IO.Path]::GetTempFileName()
        try {
            # The signed link from the job (A48), with the session too.
            Invoke-WebRequest -UseBasicParsing -Uri $job.data.download_url -Headers @{ Authorization = $auth.Authorization } -OutFile $file
            $size = (Get-Item $file).Length
            if ($size -lt 100) { throw "download only $size bytes" }
            "$size bytes downloaded"
        } finally { Remove-Item $file -ErrorAction SilentlyContinue }
    }
    Step 'request a reset code (check the inbox, and spam)' {
        $f = Call POST '/auth/forgot-password' @{ email = $Email }
        $f.data.status
    }
} finally {
    if ($auth.Authorization) {
        Step 'delete the account' {
            $d = Call DELETE '/me' @{ password = $password } @{ Authorization = $auth.Authorization }
            "deletion $($d.data.status)"
        }
    }
}
if ($script:failed) { exit 1 }
Write-Output 'Smoke test passed.'
