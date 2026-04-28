# install-snap.ps1
#
# Sideload a Snapchat APK into the running AVD via adb. Use this if you'd
# rather not sign into the Play Store inside the emulator. Provide the path
# to a Snapchat APK you've downloaded (e.g. from APKMirror — pick an
# "arm64-v8a + armeabi-v7a" universal build that matches the emulator's API
# level; on x86_64 AVDs Android translates the ARM libs automatically).

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApkPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ApkPath)) { Write-Error "APK not found: $ApkPath" }

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = "$env:LOCALAPPDATA\Android\Sdk" }
$adb = "$sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { Write-Error "adb.exe missing — run setup.ps1." }

Write-Host "Waiting for emulator..." -ForegroundColor Cyan
& $adb wait-for-device
& $adb shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done;'

Write-Host "Installing $ApkPath ..." -ForegroundColor Cyan
& $adb install -r -g $ApkPath
if ($LASTEXITCODE -ne 0) { Write-Error "adb install failed." }
Write-Host "Snapchat installed. Open it from the launcher." -ForegroundColor Green
