# Snap on Windows — the real-APK path

Goal: run the genuine Snapchat Android app on your Windows machine so that
**recipients see your messages as coming from the mobile app**, not "Snapchat
for Web."

This works by running an Android Virtual Device (AVD) that's been rooted with
Magisk and patched with the **Play Integrity Fix** module, which makes
Snapchat's anti-emulator checks pass.

> Reality check: Snapchat updates its detection. This setup works for most
> people today, but you may need to update the PIF module (or a fingerprint
> file) when Snapchat tightens checks. It's not bulletproof.

---

## Prerequisites

- **Windows 10 or 11**, with virtualization enabled in BIOS (most modern
  machines have this on by default).
- **Android Studio** — the easiest way to get the Android SDK + emulator.
  ```powershell
  winget install -e --id Google.AndroidStudio
  ```
  Open it once after installing so it provisions the SDK at
  `%LOCALAPPDATA%\Android\Sdk`. Then close it.
- **PowerShell** (built in). Run the scripts from this folder with
  `.\setup.ps1` etc. If PowerShell complains about execution policy:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

---

## Step 1 — Run setup

From this `windows\` folder:

```powershell
.\setup.ps1
```

This installs SDK packages, creates an AVD called `snap_mobile` (Pixel 6,
Android 14, Play Store), and downloads the two helpers we need into
`windows\tools\`:

- **rootAVD** — patches the AVD's ramdisk so Magisk can install.
- **PlayIntegrityFix.zip** — the Magisk module that makes integrity checks pass.

---

## Step 2 — First boot

```powershell
.\launch.ps1
```

Let the AVD finish first-run Android setup (skip Google sign-in for now, or
do it — your choice). Then **close the emulator window**.

---

## Step 3 — Root with Magisk

rootAVD modifies the emulator image while it's shut down.

```powershell
cd tools\rootAVD-master
.\rootAVD.bat ListAllAVDs
```

Copy the ramdisk path it prints for `system-images\android-34\google_apis_playstore\x86_64\ramdisk.img`. Then:

```powershell
.\rootAVD.bat system-images\android-34\google_apis_playstore\x86_64\ramdisk.img
```

When prompted, accept the defaults. It will download the latest Magisk and
patch the ramdisk.

Boot the AVD again:

```powershell
cd ..\..
.\launch.ps1
```

Open the **Magisk** app inside the AVD. It will ask to finish setup — tap
**OK** and let it reboot. After reboot, open Magisk again — it should show
**Installed** with a version number.

---

## Step 4 — Install the Play Integrity Fix module

Push the PIF zip into the emulator (with the AVD still running):

```powershell
$pif = Get-ChildItem tools\PlayIntegrityFix*.zip | Select-Object -First 1
adb push $pif.FullName /sdcard/Download/
```

(`adb` is at `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe` — the setup
script added that to your env for this session, but new shells will need
`$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"` first.)

In the emulator:

1. Open **Magisk** → **Modules** → **Install from storage**.
2. Pick the PIF zip from `Download/`.
3. Tap **Reboot** when it finishes.

After reboot, verify integrity is passing:

- Install **Play Integrity API Checker** from the Play Store (or sideload it).
- Run it. You want **MEETS_DEVICE_INTEGRITY** at minimum;
  **MEETS_STRONG_INTEGRITY** is even better. If you only get
  `MEETS_BASIC_INTEGRITY`, Snapchat will likely still detect you. See
  Troubleshooting below.

---

## Step 5 — Install Snapchat

Two options:

**A. Play Store (easiest).** Sign into Google in the AVD, open Play Store,
search "Snapchat," install.

**B. Sideload an APK.** Download a Snapchat APK from APKMirror — pick the
universal `arm64-v8a + armeabi-v7a` variant. Then:

```powershell
.\install-snap.ps1 -ApkPath C:\path\to\snapchat.apk
```

Open Snapchat, log in, send a snap to a test account, and check what your
recipient sees — no "from Snapchat for Web" tag.

---

## Daily use

Just run:

```powershell
.\launch.ps1
```

…and open Snapchat in the AVD.

---

## Troubleshooting

- **"This app isn't compatible" on Play Store** → make sure you're using the
  `google_apis_playstore` system image (the setup script does this) and that
  your Google account is signed in *after* PIF is installed.
- **PIF gives only BASIC integrity** → the bundled fingerprint may be stale.
  Grab a fresh `pif.json` from the
  [PIF discussion threads](https://xdaforums.com/) (search "PlayIntegrityFix
  fingerprints"), push it to `/data/adb/pif.json`, reboot.
- **Snapchat lets you log in but won't send snaps / says "something went wrong"**
  → device integrity is failing. Re-check the integrity checker output. Update
  PIF to the latest release, refresh the fingerprint file, reboot, retry.
- **Camera / mic prompts blank** → AVD camera defaults are off. In Android
  Studio: Tools → Device Manager → edit `snap_mobile` → Show Advanced
  Settings → set Front Camera and Back Camera to "Webcam0" (or "Emulated").
- **Slow / janky** → make sure Hyper-V or WHPX is enabled, and `-gpu host` is
  in `launch.ps1` (it is by default). 4GB RAM in the AVD config helps.
- **Magisk app missing after rootAVD** → it's there, just hidden. Open it via
  the app drawer; if not, reinstall the Magisk APK from
  https://github.com/topjohnwu/Magisk/releases via `adb install`.

---

## What lives where

```
windows\
  setup.ps1        # one-time: SDK, AVD, helper downloads
  launch.ps1       # boot the AVD
  install-snap.ps1 # adb install a Snapchat APK
  tools\
    rootAVD-master\          # Magisk-into-AVD patcher
    PlayIntegrityFix-*.zip   # Magisk module
```
