// Device mockups (native point sizes) wrapping the appScreen() replica.
// iPhone: 6.9" iPhone (440x956 pt). iPad: 13" iPad Pro (1032x1376 pt).

const PHONE = { w: 440, h: 956, radius: 55, bezel: 13, edge: 4, safeTop: 62, safeSide: 62 };
const TABLET = { w: 1032, h: 1376, radius: 22, bezel: 20, edge: 3, statusBar: 24 };

function screenContent(screenW, screenH, appOpts) {
  if (window.REAL_SCREEN) {
    return `<img src="${window.REAL_SCREEN}" style="width:${screenW}px;height:${screenH}px;object-fit:cover;display:block">`;
  }
  return appScreen({ w: screenW, h: screenH, ...appOpts });
}

function deviceShell({ sw, sh, radius, bezel, edge, screen, extras = '' }) {
  const ow = sw + 2 * (bezel + edge);
  const oh = sh + 2 * (bezel + edge);
  const html = `
  <div class="device" style="width:${ow}px;height:${oh}px;border-radius:${radius + bezel + edge}px;padding:${edge}px">
    ${extras}
    <div class="device-bezel" style="border-radius:${radius + bezel}px;padding:${bezel}px">
      <div class="device-screen" style="width:${sw}px;height:${sh}px;border-radius:${radius}px">${screen}</div>
    </div>
  </div>`;
  return { html, w: ow, h: oh };
}

function phoneDevice({ landscape = false, state, sheet = null }) {
  const sw = landscape ? PHONE.h : PHONE.w;
  const sh = landscape ? PHONE.w : PHONE.h;
  const insets = landscape
    ? { top: 0, left: PHONE.safeSide, right: PHONE.safeSide }
    : { top: PHONE.safeTop, left: 0, right: 0 };
  const island = landscape
    ? 'left:11px;top:50%;width:37px;height:126px;transform:translateY(-50%)'
    : 'top:11px;left:50%;width:126px;height:37px;transform:translateX(-50%)';
  const screen = screenContent(sw, sh, { chrome: 'phone', insets, state, sheet })
    + `<div class="island" style="${island}"></div>`;
  // Side buttons: action + volume on the left edge, power on the right (portrait orientation).
  const buttons = [
    { side: 'a', at: 196, len: 34 }, { side: 'a', at: 256, len: 62 }, { side: 'a', at: 332, len: 62 },
    { side: 'b', at: 296, len: 100 },
  ];
  const extras = buttons.map(({ side, at, len }) => {
    const style = landscape
      ? `left:${at}px;width:${len}px;height:4px;${side === 'a' ? 'bottom:-3px' : 'top:-3px'}`
      : `top:${at}px;height:${len}px;width:4px;${side === 'a' ? 'left:-3px' : 'right:-3px'}`;
    return `<div class="side-button" style="${style}"></div>`;
  }).join('');
  return deviceShell({ sw, sh, radius: PHONE.radius, bezel: PHONE.bezel, edge: PHONE.edge, screen, extras });
}

function tabletDevice({ landscape = false, state, sheet = null }) {
  const sw = landscape ? TABLET.h : TABLET.w;
  const sh = landscape ? TABLET.w : TABLET.h;
  const screen = screenContent(sw, sh, { chrome: 'tablet', insets: { top: TABLET.statusBar, left: 0, right: 0 }, state, sheet });
  // Front camera sits on the long edge, which is the top edge in landscape.
  const cam = landscape
    ? `<div class="camera" style="top:${TABLET.edge + TABLET.bezel / 2 - 3}px;left:50%;transform:translateX(-50%)"></div>`
    : `<div class="camera" style="left:${TABLET.edge + TABLET.bezel / 2 - 3}px;top:50%;transform:translateY(-50%)"></div>`;
  return deviceShell({ sw, sh, radius: TABLET.radius, bezel: TABLET.bezel, edge: TABLET.edge, screen, extras: cam });
}

// macOS window: title bar + the same ContentView in its window (macWindowSizing allows any size >= 520x460).
function macWindow({ w = 1040, h = 650, state }) {
  const titleBar = 32;
  const content = window.REAL_SCREEN
    ? `<img src="${window.REAL_SCREEN}" style="width:${w}px;height:${h}px;object-fit:cover;display:block">`
    : appScreen({ w, h, platform: 'mac', state });
  const html = `
  <div class="mac-window" style="width:${w}px;height:${h + titleBar}px">
    <div class="mac-titlebar" style="height:${titleBar}px">
      <div class="traffic"><i style="background:#ff5f57"></i><i style="background:#febc2e"></i><i style="background:#28c840"></i></div>
      Open Micer Timer
    </div>
    ${content}
  </div>`;
  return { html, w, h: h + titleBar };
}
