# A54: builds the signed release APKs (split per ABI) for a GitHub Release.
#   scripts\release-apk.ps1 -ApiBaseUrl https://<service>.onrender.com/api/v1
# arm64-v8a is the default download; armeabi-v7a is for older phones. Prints each APK's path,
# size and SHA-256. Never prints android/key.properties or any password.
param(
    [Parameter(Mandatory = $true)][string]$ApiBaseUrl,
    [string]$DownloadPageUrl = 'https://khayson.github.io/habit-system/download/',
    [string]$LegalBaseUrl = 'https://khayson.github.io/habit-system'
)
. "$PSScriptRoot\_env.ps1"

foreach ($pair in @(@('API_BASE_URL', $ApiBaseUrl), @('DOWNLOAD_PAGE_URL', $DownloadPageUrl), @('LEGAL_BASE_URL', $LegalBaseUrl))) {
    if (-not $pair[1].StartsWith('https://')) { throw "$($pair[0]) must start with https:// (release builds refuse anything else)." }
}
$keyProperties = Join-Path $AppDir 'android\key.properties'
if (-not (Test-Path $keyProperties)) {
    throw 'android\key.properties is missing: see docs\DEPLOY.md step 7 (the signing key).'
}

Push-Location $AppDir
try {
    & flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 `
        "--dart-define=API_BASE_URL=$ApiBaseUrl" `
        "--dart-define=DOWNLOAD_PAGE_URL=$DownloadPageUrl" `
        "--dart-define=LEGAL_BASE_URL=$LegalBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}

$version = (Select-String -Path (Join-Path $AppDir 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
Write-Output ''
Write-Output "Habit System $version"
foreach ($abi in @('arm64-v8a', 'armeabi-v7a')) {
    $apk = Join-Path $AppDir "build\app\outputs\flutter-apk\app-$abi-release.apk"
    if (-not (Test-Path $apk)) { throw "Expected $apk after the build." }
    $item = Get-Item $apk
    $hash = (Get-FileHash -Algorithm SHA256 $apk).Hash.ToLowerInvariant()
    Write-Output ("{0,-12} {1,10:N0} bytes  sha256 {2}" -f $abi, $item.Length, $hash)
    Write-Output "             $apk"
}
Write-Output ''
Write-Output 'Upload both to a new GitHub Release (docs\DEPLOY.md step 8); paste the SHA-256 lines into its notes.'
