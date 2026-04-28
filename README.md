# Snap

Tools for using Snapchat from a non-phone, with two different goals.

## Which one do you want?

| If your goal is…                                                              | Use this                |
|-------------------------------------------------------------------------------|-------------------------|
| Recipients see your messages as **coming from the phone app** (no "from Web") | [`windows/`](windows/)  |
| Just a phone-shaped UI for browsing Snapchat on your computer                 | [`src/`](src/) (Electron) |

The **Electron wrapper** spoofs your browser into looking like a Pixel 7 Pro
so `web.snapchat.com` renders as the mobile site. It's lightweight, but it
**cannot** change what your recipients see — Snapchat tags messages
server-side based on the API client they came from, and the web bundle
identifies itself as "Snapchat for Web" no matter what your User-Agent says.

The **Windows AVD path** runs the actual Snapchat Android app inside a rooted
Android emulator with Play Integrity Fix, so to Snapchat's servers you are
indistinguishable from a Pixel phone. This is the one that hides the "from
Web" tag.

## Electron wrapper (any OS)

```bash
npm install
npm start
```

See [`src/main.js`](src/main.js) for the device profile and CDP emulation,
and [`src/preload.js`](src/preload.js) for the `navigator` patches.

## Windows real-APK path

See [`windows/README.md`](windows/README.md) for the full step-by-step. TL;DR:

```powershell
cd windows
.\setup.ps1     # one-time: SDK, AVD, downloads
.\launch.ps1    # boot the AVD
# then root with rootAVD, install Magisk + PlayIntegrityFix, install Snapchat
```
