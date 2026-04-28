// Runs in the page's isolated world before any page script. We patch the
// JavaScript-visible navigator surface so feature detection inside Snapchat's
// web bundle treats us as a mobile Android device, on top of the
// CDP-level emulation done in main.js.

const PLATFORM = 'Linux armv8l';
const VENDOR = 'Google Inc.';
const MAX_TOUCH_POINTS = 5;
const HARDWARE_CONCURRENCY = 8;
const DEVICE_MEMORY = 8;

function defineProp(obj, key, value) {
  try {
    Object.defineProperty(obj, key, {
      get: () => value,
      configurable: true,
    });
  } catch (_) {
    /* noop */
  }
}

defineProp(Navigator.prototype, 'platform', PLATFORM);
defineProp(Navigator.prototype, 'vendor', VENDOR);
defineProp(Navigator.prototype, 'maxTouchPoints', MAX_TOUCH_POINTS);
defineProp(Navigator.prototype, 'hardwareConcurrency', HARDWARE_CONCURRENCY);
defineProp(Navigator.prototype, 'deviceMemory', DEVICE_MEMORY);

// userAgentData (Client Hints) — match the headers from main.js.
const uaData = {
  brands: [
    { brand: 'Chromium', version: '126' },
    { brand: 'Google Chrome', version: '126' },
    { brand: 'Not.A/Brand', version: '24' },
  ],
  mobile: true,
  platform: 'Android',
  getHighEntropyValues: (hints) => {
    const values = {
      architecture: '',
      bitness: '64',
      brands: uaData.brands,
      fullVersionList: [
        { brand: 'Chromium', version: '126.0.6478.71' },
        { brand: 'Google Chrome', version: '126.0.6478.71' },
        { brand: 'Not.A/Brand', version: '24.0.0.0' },
      ],
      mobile: true,
      model: 'Pixel 7 Pro',
      platform: 'Android',
      platformVersion: '14.0.0',
      uaFullVersion: '126.0.6478.71',
      wow64: false,
    };
    const out = {};
    (hints || []).forEach((h) => {
      if (h in values) out[h] = values[h];
    });
    return Promise.resolve(out);
  },
  toJSON: () => ({
    brands: uaData.brands,
    mobile: uaData.mobile,
    platform: uaData.platform,
  }),
};
defineProp(Navigator.prototype, 'userAgentData', uaData);

// Mark the window as touch-capable for any code that sniffs this directly.
if (!('ontouchstart' in window)) {
  try {
    Object.defineProperty(window, 'ontouchstart', {
      value: null,
      configurable: true,
    });
  } catch (_) {
    /* noop */
  }
}

// Some sites detect mobile by checking that there is no fine pointer. CDP's
// device emulation already updates matchMedia, but we double-check the common
// queries to make sure they answer "mobile-shaped".
const realMatchMedia = window.matchMedia.bind(window);
window.matchMedia = (query) => {
  const result = realMatchMedia(query);
  if (typeof query === 'string') {
    if (query.includes('hover: hover') || query.includes('pointer: fine')) {
      return { ...result, matches: false, media: query };
    }
    if (query.includes('hover: none') || query.includes('pointer: coarse')) {
      return { ...result, matches: true, media: query };
    }
  }
  return result;
};
