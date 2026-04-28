const { app, BrowserWindow, session, Menu } = require('electron');
const path = require('path');

// Pixel 7 Pro - a believable, modern Android device that Snapchat fully supports.
const DEVICE = {
  name: 'Pixel 7 Pro',
  userAgent:
    'Mozilla/5.0 (Linux; Android 14; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.6478.71 Mobile Safari/537.36',
  width: 412,
  height: 892,
  deviceScaleFactor: 3.5,
  platform: 'Linux armv8l',
};

// Window chrome adds a bit of vertical space; the inner web area should still
// match the device viewport.
const WINDOW_PADDING_HEIGHT = 0;

function applyMobileHeaders(ses) {
  ses.webRequest.onBeforeSendHeaders((details, callback) => {
    const headers = { ...details.requestHeaders };
    headers['User-Agent'] = DEVICE.userAgent;
    headers['sec-ch-ua'] =
      '"Chromium";v="126", "Google Chrome";v="126", "Not.A/Brand";v="24"';
    headers['sec-ch-ua-mobile'] = '?1';
    headers['sec-ch-ua-platform'] = '"Android"';
    headers['sec-ch-ua-platform-version'] = '"14.0.0"';
    headers['sec-ch-ua-model'] = '"Pixel 7 Pro"';
    callback({ requestHeaders: headers });
  });
}

async function emulateDevice(webContents) {
  // Tell Chromium to behave like a touch-only mobile device with the right
  // pixel ratio and viewport. This affects window.matchMedia, touch events,
  // devicePixelRatio, and screen size.
  await webContents.debugger.attach('1.3').catch(() => {});

  try {
    await webContents.debugger.sendCommand('Emulation.setDeviceMetricsOverride', {
      width: DEVICE.width,
      height: DEVICE.height,
      deviceScaleFactor: DEVICE.deviceScaleFactor,
      mobile: true,
      screenWidth: DEVICE.width,
      screenHeight: DEVICE.height,
      positionX: 0,
      positionY: 0,
      screenOrientation: { type: 'portraitPrimary', angle: 0 },
    });

    await webContents.debugger.sendCommand('Emulation.setTouchEmulationEnabled', {
      enabled: true,
      maxTouchPoints: 5,
    });

    await webContents.debugger.sendCommand('Emulation.setEmitTouchEventsForMouse', {
      enabled: true,
      configuration: 'mobile',
    });

    await webContents.debugger.sendCommand('Emulation.setUserAgentOverride', {
      userAgent: DEVICE.userAgent,
      platform: DEVICE.platform,
      userAgentMetadata: {
        brands: [
          { brand: 'Chromium', version: '126' },
          { brand: 'Google Chrome', version: '126' },
          { brand: 'Not.A/Brand', version: '24' },
        ],
        fullVersion: '126.0.6478.71',
        platform: 'Android',
        platformVersion: '14.0.0',
        architecture: '',
        model: 'Pixel 7 Pro',
        mobile: true,
      },
    });
  } catch (err) {
    console.error('Failed to apply CDP emulation:', err);
  }
}

function createWindow() {
  const win = new BrowserWindow({
    width: DEVICE.width,
    height: DEVICE.height + WINDOW_PADDING_HEIGHT,
    useContentSize: true,
    resizable: true,
    title: 'Snap',
    backgroundColor: '#000000',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      sandbox: false,
      partition: 'persist:snap-mobile',
    },
  });

  // Set the UA at the BrowserWindow level too so initial requests also match.
  win.webContents.setUserAgent(DEVICE.userAgent);

  applyMobileHeaders(win.webContents.session);

  win.webContents.on('dom-ready', () => {
    emulateDevice(win.webContents);
  });

  // Re-apply emulation after navigations (the debugger attach persists, but
  // some sites trigger full reloads; this keeps things consistent).
  win.webContents.on('did-navigate', () => {
    emulateDevice(win.webContents);
  });

  win.loadURL('https://web.snapchat.com/');

  // A minimal menu — just enough for reload, devtools, copy/paste.
  const menu = Menu.buildFromTemplate([
    {
      label: 'App',
      submenu: [
        { role: 'reload' },
        { role: 'forceReload' },
        { role: 'toggleDevTools' },
        { type: 'separator' },
        { role: 'quit' },
      ],
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' },
        { role: 'redo' },
        { type: 'separator' },
        { role: 'cut' },
        { role: 'copy' },
        { role: 'paste' },
        { role: 'selectAll' },
      ],
    },
  ]);
  Menu.setApplicationMenu(menu);
}

// Spoof the UA on the default session before any window is created so that
// even pre-load network calls (favicon, manifest, etc.) look mobile.
app.userAgentFallback = DEVICE.userAgent;

app.whenReady().then(() => {
  applyMobileHeaders(session.defaultSession);
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
