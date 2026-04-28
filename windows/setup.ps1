# setup.ps1
#
# One-time setup for the Snap-on-Windows pipeline. After this finishes you
# still have to run rootAVD interactively and install a couple of Magisk
# modules from inside the booted Android — see windows\README.md for the
# rest of the steps.
#
# What this script does:
#   1. Verifies Android Studio / Android SDK is present (or tells you how to install it).
#   2. Installs platform-tools, emulator, and the Pixel Play Store system image.
#   3. Creates an AVD named "snap_mobile" using the Pixel 6 hardware profile.
#   4. Downloads rootAVD (used to inject Magisk into the AVD).
#   5. Downloads the latest Play Integrity Fix Magisk module zip.
#
# Run from PowerShell:   .\setup.ps1

[CmdletBinding()]
param(
    [string]$AvdName = 'snap_mobile',
    [string]$AndroidApi = '34',
    [string]$SystemImage = 'system-images;android-34;google_apis_playstore;x86_64'
)

$ErrorActionPreference = 'Stop'

function Resolve-AndroidSdk {
    foreach ($candidate in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk")) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

$sdk = Resolve-AndroidSdk
if (-not $sdk) {
    Write-Host "Android SDK not found." -ForegroundColor Yellow
    Write-Host "Install Android Studio first, then re-run this script. Easiest:" -ForegroundColor Yellow
    Write-Host "    winget install -e --id Google.AndroidStudio" -ForegroundColor Cyan
    Write-Host "Open Android Studio once so it provisions the SDK at %LOCALAPPDATA%\Android\Sdk."
    exit 1
}
Write-Host "Using Android SDK: $sdk" -ForegroundColor Green
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk

# sdkmanager lives in different spots depending on Android Studio version.
$sdkmanager = @(
    "$sdk\cmdline-tools\latest\bin\sdkmanager.bat",
    "$sdk\cmdline-tools\bin\sdkmanager.bat",
    "$sdk\tools\bin\sdkmanager.bat"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $sdkmanager) {
    Write-Error "sdkmanager.bat not found. Open Android Studio > More Actions > SDK Manager > SDK Tools tab and install 'Android SDK Command-line Tools (latest)', then re-run."
}
$avdmanager = $sdkmanager.Replace('sdkmanager.bat', 'avdmanager.bat')
$emulator = "$sdk\emulator\emulator.exe"
$adb = "$sdk\platform-tools\adb.exe"

Write-Host "Installing required SDK packages (this takes a few minutes)..." -ForegroundColor Cyan
& $sdkmanager --install 'platform-tools' 'emulator' "platforms;android-$AndroidApi" $SystemImage
if ($LASTEXITCODE -ne 0) { Write-Error "sdkmanager failed." }

Write-Host "Creating AVD '$AvdName' (Pixel 6 hardware profile)..." -ForegroundColor Cyan
$existing = & $avdmanager list avd 2>$null
if ($existing -match "Name:\s+$AvdName") {
    Write-Host "AVD '$AvdName' already exists, leaving it alone." -ForegroundColor Yellow
} else {
    'no' | & $avdmanager create avd --name $AvdName --package $SystemImage --device 'pixel_6'
    if ($LASTEXITCODE -ne 0) { Write-Error "avdmanager create failed." }

    # Bump RAM and disk so Snapchat's media features don't choke.
    $cfg = "$env:USERPROFILE\.android\avd\$AvdName.avd\config.ini"
    if (Test-Path $cfg) {
        $lines = Get-Content $cfg
        $lines = $lines | Where-Object { $_ -notmatch '^(hw\.ramSize|disk\.dataPartition\.size|hw\.gpu\.enabled|hw\.gpu\.mode|hw\.keyboard|hw\.camera\.front|hw\.camera\.back)\s*=' }
        $lines += @(
            'hw.ramSize=4096',
            'disk.dataPartition.size=8192M',
            'hw.gpu.enabled=yes',
            'hw.gpu.mode=host',
            'hw.keyboard=yes',
            'hw.camera.front=webcam0',
            'hw.camera.back=webcam0'
        )
        Set-Content -Path $cfg -Value $lines
    }
}

# Download helpers into a tools/ folder next to this script.
$tools = Join-Path $PSScriptRoot 'tools'
New-Item -ItemType Directory -Path $tools -Force | Out-Null

$rootAvdZip = Join-Path $tools 'rootAVD.zip'
if (-not (Test-Path $rootAvdZip)) {
    Write-Host "Downloading rootAVD..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri 'https://gitlab.com/newbit/rootAVD/-/archive/master/rootAVD-master.zip' -OutFile $rootAvdZip
    Expand-Archive -Path $rootAvdZip -DestinationPath $tools -Force
}

Write-Host "Looking up latest Play Integrity Fix release..." -ForegroundColor Cyan
$pifApi = 'https://api.github.com/repos/chiteroman/PlayIntegrityFix/releases/latest'
$pif = Invoke-RestMethod -Uri $pifApi -Headers @{ 'User-Agent' = 'snap-mobile-setup' }
$pifAsset = $pif.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
if ($pifAsset) {
    $pifPath = Join-Path $tools $pifAsset.name
    if (-not (Test-Path $pifPath)) {
        Invoke-WebRequest -Uri $pifAsset.browser_download_url -OutFile $pifPath
    }
    Write-Host "PIF module: $pifPath" -ForegroundColor Green
} else {
    Write-Warning "Couldn't find PIF release asset. Grab it manually from https://github.com/chiteroman/PlayIntegrityFix/releases"
}

@"

Setup done.

Tools downloaded to: $tools
SDK:                 $sdk
Emulator:            $emulator
ADB:                 $adb

Next steps (see windows\README.md for the full walkthrough):
  1. .\launch.ps1                     # boot the AVD once and let it finish first-run setup, then close it
  2. cd tools\rootAVD-master
     .\rootAVD.bat ListAllAVDs        # find your AVD's ramdisk path
     .\rootAVD.bat <ramdisk path>     # patch it with Magisk
  3. .\launch.ps1                     # boot again, open Magisk app, accept the prompt to finish install, reboot
  4. Push the PIF zip into the emulator and install it from Magisk:
        adb push tools\$($pifAsset.name) /sdcard/Download/
     Then in Magisk > Modules > Install from storage, pick that file, reboot.
  5. Sign into Google Play (in the emulator), then install Snapchat from the Play Store.
"@ | Write-Host
