# Snap Mobile

A tiny Electron wrapper that opens `web.snapchat.com` while pretending to be a
**Pixel 7 Pro running Android 14**, so the page renders and behaves like the
phone app instead of the desktop "Snapchat for Web" experience.

## What it does

- Spoofs the User-Agent on every request (top frame, sub-resources, fetch/XHR).
- Sets matching Client Hints headers (`sec-ch-ua-*`) and `navigator.userAgentData`.
- Uses the Chrome DevTools Protocol to fully emulate a mobile device:
  - mobile viewport (412×892), 3.5x DPR, portrait orientation
  - touch input + `ontouchstart`, 5 touch points
  - `hover:none` / `pointer:coarse` media queries
- Patches `navigator.platform`, `vendor`, `maxTouchPoints`,
  `hardwareConcurrency`, `deviceMemory`.
- Persists your login in a dedicated session partition.

## Run it

```bash
npm install
npm start
```

That's it — the app opens a phone-shaped window pointed at Snapchat.

## Files

- `src/main.js` — Electron main process: window, headers, CDP emulation.
- `src/preload.js` — Page-side patches to `navigator` and `matchMedia`.
- `package.json` — Electron entry point + scripts.

## Notes

Snapchat's server-side "sent from Snapchat for Web" indicator (the one your
recipients see) is driven by the API client identifier baked into the web
bundle, not by your browser's User-Agent. Spoofing the device makes the
**experience** mobile, but it cannot change what the recipient's app labels
the message as. If you need the recipient to see "from mobile", you'll need
to use the actual mobile app or an Android emulator (e.g. Waydroid, Genymotion,
BlueStacks) running the real Snapchat APK.
