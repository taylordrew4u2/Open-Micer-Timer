// Screenshot sets: canvas sizes, captions and the scene shown on each slide.

const CANVASES = {
  'iPhone-6.5_1284x2778': { w: 428, h: 926, scale: 3, kind: 'phone', u: 0.97 },
  'iPhone-6.5_1242x2688': { w: 414, h: 896, scale: 3, kind: 'phone', u: 0.94 },
  'iPhone-6.9_1320x2868': { w: 440, h: 956, scale: 3, kind: 'phone', u: 1 },
  'iPad-13_2064x2752': { w: 1032, h: 1376, scale: 2, kind: 'tablet', u: 1.95 },
  'Mac_2880x1800': { w: 1440, h: 900, scale: 2, kind: 'mac', u: 1.25 },
};

const STATES = {
  ready: { total: 300, remaining: 300 },
  running: { total: 300, remaining: 207, running: true },
  final: { total: 300, remaining: 42, running: true },
  time: { total: 300, remaining: 0 },
  custom: { total: 450, remaining: 450 },
  longSet: { total: 600, remaining: 552, running: true },
  finalLate: { total: 300, remaining: 23, running: true },
};

const COPY = {
  countdown: {
    kicker: 'Open mic stage timer',
    title: 'Big enough to <em>read from the mic.</em>',
    sub: 'Huge, high-contrast numbers fill the whole screen.',
  },
  remote: {
    kicker: 'Hands-free',
    title: 'Start &amp; stop with <em>your headphones.</em>',
    sub: 'Bluetooth play/pause, media remotes and presentation clickers toggle the timer.',
  },
  remoteMac: {
    kicker: 'Hands-free',
    title: 'Start &amp; stop <em>without reaching over.</em>',
    sub: 'Space, Return or Bluetooth play/pause toggle the timer.',
  },
  final: {
    kicker: 'The light, built in',
    title: 'The last minute <em>can’t be missed.</em>',
    sub: 'The screen turns yellow and the seconds go giant: 59, 58, 57…',
  },
  time: {
    kicker: 'Hard stop',
    title: 'Time’s up? <em>Everyone knows.</em>',
    sub: 'A big red 0:00 the moment the set ends.',
  },
  settings: {
    kicker: 'Any set length',
    title: 'Tight five to <em>headliner set.</em>',
    sub: 'Pick 1 to 120 minutes in 5-second steps, plus stage display options.',
  },
  anyScreen: {
    kicker: 'iPhone &amp; iPad',
    title: 'Fills any screen, <em>any way you hold it.</em>',
    sub: 'Portrait or landscape, the timer scales edge to edge.',
  },
};

// scene: { device: 'phone'|'tablet'|'mac', landscape, state, sheet } or { multi: 'phone'|'tablet' }
const SLIDES = {
  phone: [
    { id: '01-giant-countdown', copy: COPY.countdown, scene: { device: 'phone', state: STATES.ready } },
    { id: '02-bluetooth-remote', copy: COPY.remote, scene: { device: 'phone', state: STATES.running }, callout: 'remote' },
    { id: '03-final-minute', copy: COPY.final, theme: 'yellow', scene: { device: 'phone', state: STATES.final } },
    { id: '04-times-up', copy: COPY.time, glow: 'red', scene: { device: 'phone', state: STATES.time } },
    { id: '05-any-set-length', copy: COPY.settings, scene: { device: 'phone', state: STATES.custom, sheet: 'settings' } },
    { id: '06-any-screen', copy: COPY.anyScreen, scene: { multi: 'phone' } },
  ],
  tablet: [
    { id: '01-giant-countdown', copy: COPY.countdown, scene: { device: 'tablet', state: STATES.ready } },
    { id: '02-bluetooth-remote', copy: COPY.remote, scene: { device: 'tablet', landscape: true, state: STATES.running }, callout: 'remote' },
    { id: '03-final-minute', copy: COPY.final, theme: 'yellow', scene: { device: 'tablet', state: STATES.final } },
    { id: '04-times-up', copy: COPY.time, glow: 'red', scene: { device: 'tablet', state: STATES.time } },
    { id: '05-any-set-length', copy: COPY.settings, scene: { device: 'tablet', state: STATES.custom, sheet: 'settings' } },
    { id: '06-any-screen', copy: { ...COPY.anyScreen, kicker: 'iPad &amp; iPhone' }, scene: { multi: 'tablet' } },
  ],
  mac: [
    { id: '01-giant-countdown', copy: COPY.countdown, scene: { device: 'mac', state: STATES.ready } },
    { id: '02-hands-free', copy: COPY.remoteMac, scene: { device: 'mac', state: STATES.running }, callout: 'keys' },
    { id: '03-final-minute', copy: COPY.final, theme: 'yellow', scene: { device: 'mac', state: STATES.final } },
    { id: '04-times-up', copy: COPY.time, glow: 'red', scene: { device: 'mac', state: STATES.time } },
  ],
};

function slideIds(canvasName) {
  return SLIDES[CANVASES[canvasName].kind].map((s) => s.id);
}

function buildDevice(scene) {
  if (scene.device === 'phone') return phoneDevice(scene);
  if (scene.device === 'tablet') return tabletDevice(scene);
  return macWindow(scene);
}

function placeDevice(stage, device, x, y, s, z = 1) {
  const wrap = document.createElement('div');
  wrap.className = 'placed';
  Object.assign(wrap.style, { left: `${x}px`, top: `${y}px`, width: `${device.w * s}px`, height: `${device.h * s}px`, zIndex: z });
  wrap.innerHTML = `<div style="width:${device.w}px;height:${device.h}px;transform:scale(${s});transform-origin:0 0">${device.html}</div>`;
  stage.appendChild(wrap);
  return { x, y, w: device.w * s, h: device.h * s };
}

function layoutSingle(stage, scene, box, kind) {
  const device = buildDevice(scene);
  const maxW = box.w * (kind === 'mac' ? 0.86 : scene.landscape ? 0.9 : 0.84);
  const s = Math.min(maxW / device.w, box.h / device.h);
  const w = device.w * s, h = device.h * s;
  return placeDevice(stage, device, (box.w - w) / 2, box.y + (box.h - h) / 2, s);
}

function layoutMulti(stage, kind, box) {
  if (kind === 'phone') {
    // iPad (portrait) behind, iPhone (landscape) in front, overlapping its lower half.
    const back = tabletDevice({ state: STATES.longSet });
    const front = phoneDevice({ landscape: true, state: STATES.finalLate });
    const sb = Math.min((box.w * 0.86) / back.w, (box.h * 0.82) / back.h);
    const sf = (box.w * 0.94) / front.w;
    const overlap = front.h * sf * 0.55;
    const groupH = back.h * sb + front.h * sf - overlap;
    const top = box.y + Math.max(0, (box.h - groupH) / 2);
    const b = placeDevice(stage, back, (box.w - back.w * sb) / 2, top, sb, 1);
    placeDevice(stage, front, (box.w - front.w * sf) / 2, b.y + b.h - overlap, sf, 2);
    return b;
  }
  // iPad (landscape) behind, iPhone (portrait) in front on the right.
  const back = tabletDevice({ landscape: true, state: STATES.longSet });
  const front = phoneDevice({ state: STATES.finalLate });
  const sb = (box.w * 0.84) / back.w;
  const sf = (box.h * 0.72) / front.h;
  const groupH = Math.max(back.h * sb, back.h * sb * 0.42 + front.h * sf);
  const top = box.y + Math.max(0, (box.h - groupH) / 2);
  const b = placeDevice(stage, back, box.w * 0.05, top, sb, 1);
  placeDevice(stage, front, box.w * 0.95 - front.w * sf, top + b.h * 0.42, sf, 2);
  return b;
}

function callout(kind, anchor, canvas) {
  const content = kind === 'keys'
    ? { ic: 'playPause', title: 'Space or Return', body: 'or Bluetooth play/pause' }
    : { ic: 'headphones', title: 'Play / Pause', body: 'starts and stops the timer' };
  const el = document.createElement('div');
  el.className = 'callout';
  el.innerHTML = `
    <div class="callout-icon">${icon(content.ic, 22, '#000')}</div>
    <div><div class="callout-title">${content.title}</div><div class="callout-body">${content.body}</div></div>`;
  // Park the callout in empty stage space so it never covers the countdown.
  if (canvas.kind === 'phone') {
    el.style.left = '14px';
    el.style.top = `${anchor.y + anchor.h * 0.6}px`;
  } else if (canvas.kind === 'tablet') {
    el.style.setProperty('--u', canvas.u * 0.8);
    el.style.right = `${canvas.w - anchor.x - anchor.w - 20 * canvas.u}px`;
    el.style.top = `${anchor.y + anchor.h * 0.63}px`;
  } else {
    el.style.left = `${anchor.x - 80 * canvas.u}px`;
    el.style.top = `${anchor.y + anchor.h * 0.42}px`;
  }
  return el;
}

async function renderSlide(canvasName, slideId) {
  const canvas = CANVASES[canvasName];
  const slide = SLIDES[canvas.kind].find((s) => s.id === slideId);
  if (!slide) throw new Error(`Unknown slide ${slideId} for ${canvasName}`);

  const root = document.getElementById('canvas');
  root.className = `canvas kind-${canvas.kind} theme-${slide.theme || 'dark'}`;
  root.style.cssText = `width:${canvas.w}px;height:${canvas.h}px;--u:${canvas.u}`;
  root.innerHTML = `
    <div class="glow ${slide.glow || ''}"></div>
    <div class="caption">
      <div class="kicker">${slide.copy.kicker}</div>
      <h1>${slide.copy.title}</h1>
      <p>${slide.copy.sub}</p>
    </div>
    <div class="stage"></div>`;

  await document.fonts.ready;
  const caption = root.querySelector('.caption');
  const stage = root.querySelector('.stage');
  const gap = 26 * canvas.u;
  const bottom = (canvas.kind === 'mac' ? 46 : 34) * canvas.u;
  const box = { y: caption.offsetTop + caption.offsetHeight + gap, w: canvas.w };
  box.h = canvas.h - box.y - bottom;

  const anchor = slide.scene.multi
    ? layoutMulti(stage, slide.scene.multi, box)
    : layoutSingle(stage, slide.scene, box, canvas.kind);

  const glow = root.querySelector('.glow');
  glow.style.left = `${anchor.x + anchor.w / 2}px`;
  glow.style.top = `${anchor.y + anchor.h * 0.5}px`;

  if (slide.callout) stage.appendChild(callout(slide.callout, anchor, canvas));
  fitAppText(root);
}
