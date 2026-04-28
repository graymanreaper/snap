# launch.ps1
#
# Boots the snap_mobile AVD with sensible flags. Run any time you want to
# use Snapchat after the one-time setup is done.

[CmdletBinding()]
param(
    [string]$AvdName = 'snap_mobile'
)

$ErrorActionPreference = 'Stop'

function Resolve-AndroidSdk {
    foreach ($candidate in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk")) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

$sdk = Resolve-AndroidSdk
if (-not $sdk) { Write-Error "Android SDK not found. Run setup.ps1 first." }
$emulator = "$sdk\emulator\emulator.exe"
if (-not (Test-Path $emulator)) { Write-Error "emulator.exe missing. Re-run setup.ps1." }

# -no-snapshot-save  -> always fresh boot, helps PIF re-seed device props on each launch
# -gpu host          -> hardware acceleration so the camera/UI is usable
# -netdelay/-netspeed -> remove emulator-default network throttling
& $emulator -avd $AvdName -no-snapshot-save -gpu host -netdelay none -netspeed full
