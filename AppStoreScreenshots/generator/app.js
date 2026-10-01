// HTML replica of the stage timer screen in "Open Micer Timer/ContentView.swift".
// Layout numbers mirror StageLayout and the view builders there, so keep the two in sync
// when the SwiftUI layout changes.

const YELLOW = 'rgb(255, 189, 41)';            // Color(red: 1, green: 0.74, blue: 0.16)
const RED = 'rgb(255, 69, 58)';                // systemRed, dark appearance
const GREEN = 'rgb(48, 209, 88)';              // systemGreen, dark appearance

function icon(name, size, color, extraStyle = '') {
  return `<svg class="ic" viewBox="0 0 256 256" width="${size}" height="${size}" fill="${color}" style="flex:none;${extraStyle}">${ICONS[name]}</svg>`;
}

function stageLayout(w, h, platform) {
  const isLandscape = w > h;
  const isCompact = Math.min(w, h) < 390;
  const outerPadding = Math.min(Math.max(w * 0.045, 16), 44);
  return {
    w, h, isLandscape, isCompact, outerPadding,
    isVeryShort: h < 420,
    useWideControls: isLandscape && w >= (platform === 'mac' ? 900 : 760),
    contentMaxWidth: platform === 'mac' ? Math.min(Math.max(w * 0.9, 520), 980) : null,
    topPadding: isCompact ? 8 : 14,
    bottomPadding: isCompact ? 14 : 22,
    timerHorizontalPadding: isLandscape ? outerPadding : Math.max(10, outerPadding * 0.55),
    verticalSpacing: isCompact ? 10 : 18,
    controlSpacing: isCompact ? 10 : 14,
    controlHeight: isCompact ? 48 : 56,
    iconButtonSize: isCompact ? 48 : 56,
    controlPadding: isCompact ? 8 : 12,
    progressHeightMultiplier: isCompact ? 3 : 4,
  };
}

function timerModel(s) {
  const total = s.total ?? 300;
  const remaining = s.remaining ?? total;
  const running = !!s.running;
  const finalMode = s.finalMode !== false;
  const isFinal = finalMode && remaining > 0 && remaining <= 60;
  const displayed = isFinal && remaining < 60
    ? String(remaining)
    : `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, '0')}`;
  const status = remaining === 0 ? 'TIME'
    : isFinal ? (remaining === 60 ? 'ONE MINUTE' : 'FINAL COUNTDOWN')
    : running ? 'RUNNING' : 'READY';
  return {
    total, remaining, running, isFinal, displayed, status,
    showHint: s.showHint !== false,
    progress: total > 0 ? remaining / total : 0,
    statusIcon: remaining === 0 ? 'flag' : isFinal ? 'warning' : running ? 'timer' : 'playCircle',
    progressColor: remaining === 0 ? RED : isFinal ? '#000' : running ? YELLOW : 'rgba(255,255,255,.7)',
    timerColor: remaining === 0 ? RED : isFinal ? '#000' : '#fff',
    badgeBackground: remaining === 0 ? RED : isFinal ? 'rgba(0,0,0,.82)' : running ? 'rgba(255,189,41,.24)' : 'rgba(255,255,255,.12)',
    subLabel: running ? 'RUNNING' : remaining === 0 ? 'TIME' : 'READY',
  };
}

function timerFontSize(L, m) {
  if (m.isFinal) return L.isLandscape ? L.h * 0.76 : L.w * 0.64;
  if (L.isLandscape) return Math.min(L.w * 0.24, L.h * 0.6);
  return Math.min(L.w * 0.36, L.h * 0.27);
}

function stageIconButton(name) {
  return `<div class="stage-icon-btn">${icon(name, 19, '#fff')}</div>`;
}

function headerStrip(L, m) {
  return `
  <div class="header" style="padding:${L.topPadding}px ${L.outerPadding}px 0">
    <img class="logo" src="${LOGO_SRC}">
    <div class="badge fit-badge" style="font-size:${L.isCompact ? 15 : 18}px;padding:${L.isCompact ? 8 : 10}px ${L.isCompact ? 12 : 16}px;background:${m.badgeBackground}">
      ${icon(m.statusIcon, L.isCompact ? 16 : 19, '#fff')}<span>${m.status}</span>
    </div>
    <div class="spacer"></div>
    ${L.isCompact ? '' : '<div class="header-hint fit-hint">Bluetooth: play/pause toggles timer</div>'}
    ${stageIconButton('question')}
    ${stageIconButton('gearshape')}
  </div>`;
}

function timerDisplay(L, m) {
  return `
  <div class="timer-box" style="padding:0 ${L.timerHorizontalPadding}px">
    <div class="timer-stack" style="gap:${m.isFinal ? 6 : 8}px">
      <div class="timer-text fit-timer" data-size="${timerFontSize(L, m)}" style="color:${m.timerColor};text-shadow:${m.isFinal ? 'none' : `0 4px 12px ${m.timerColor === '#fff' ? 'rgba(255,255,255,.24)' : 'rgba(255,69,58,.24)'}`}">${m.displayed}</div>
      ${m.isFinal ? '' : `<div class="timer-sub">${m.subLabel}</div>`}
    </div>
  </div>`;
}

function progressBar(L, m) {
  const thickness = 4 * L.progressHeightMultiplier;
  const track = m.isFinal ? 'rgba(0,0,0,.18)' : 'rgba(120,120,128,.36)';
  return `
  <div class="progress" style="margin:0 ${L.outerPadding}px">
    <div class="progress-bar" style="height:${thickness}px;top:${(4 - thickness) / 2}px;background:${track}">
      <div style="width:${m.progress * 100}%;background:${m.progressColor}"></div>
    </div>
  </div>`;
}

function stageControls(L, m) {
  const startTint = m.running ? RED : YELLOW;
  const resetDisabled = m.running && m.remaining > 0;
  const bordered = (name, disabled) => `
    <div class="btn bordered${disabled ? ' disabled' : ''}" style="min-width:${L.iconButtonSize}px;height:${L.controlHeight}px">
      ${icon(name, 20, disabled ? 'rgba(60,60,67,.3)' : YELLOW)}
    </div>`;
  return `
  <div class="controls" style="padding:${L.controlPadding}px;background:rgba(255,255,255,${m.isFinal ? 0.94 : 0.9})">
    <div class="btn prominent" style="height:${L.controlHeight}px;background:${startTint}">
      ${icon(m.running ? 'stop' : 'play', 19, '#fff')}<span>${m.running ? 'Stop' : 'Start'}</span>
    </div>
    ${bordered('reset', resetDisabled)}
    ${bordered('gearshape', false)}
  </div>`;
}

function remoteHint(compact) {
  return `
  <div class="remote-hint" style="padding:${compact ? 12 : 14}px">
    <div class="remote-hint-icon">${icon('headphones', 22, '#fff')}</div>
    <div>
      <div class="remote-hint-title">Bluetooth headphones</div>
      <div class="remote-hint-body">${compact ? 'Play/pause starts or stops.' : 'Press play/pause once to start and again to stop. Keep this screen visible for the performer.'}</div>
    </div>
  </div>`;
}

function bottomPanel(L, m) {
  const pad = `padding:0 ${L.outerPadding}px ${L.bottomPadding}px`;
  if (L.useWideControls) {
    return `
    <div class="bottom wide" style="${pad};gap:${L.controlSpacing}px">
      <div style="flex:1 1 0;max-width:520px">${stageControls(L, m)}</div>
      ${m.showHint ? `<div style="flex:1 1 0;max-width:420px">${remoteHint(false)}</div>` : ''}
    </div>`;
  }
  return `
  <div class="bottom" style="${pad};gap:${L.controlSpacing}px">
    ${stageControls(L, m)}
    ${m.showHint && !L.isVeryShort ? remoteHint(L.isCompact) : ''}
  </div>`;
}

// iOS status bar for the given screen width, white glyphs (dark appearance).
function statusBar(kind, w) {
  const color = '#fff';
  const signal = `<svg width="19" height="12" viewBox="0 0 19 12" fill="${color}"><rect x="0" y="7.5" width="3.2" height="4.5" rx="1"/><rect x="5" y="5" width="3.2" height="7" rx="1"/><rect x="10" y="2.5" width="3.2" height="9.5" rx="1"/><rect x="15" y="0" width="3.2" height="12" rx="1"/></svg>`;
  const wifi = `<svg width="17" height="12" viewBox="0 0 17 12" fill="${color}"><path d="M8.5 2.3c2.4 0 4.6.9 6.3 2.5.1.1.3.1.4 0l1.2-1.2c.1-.1.1-.3 0-.4C14.3 1.2 11.5 0 8.5 0S2.7 1.2.6 3.2c-.1.1-.1.3 0 .4l1.2 1.2c.1.1.3.1.4 0C3.9 3.2 6.1 2.3 8.5 2.3Zm0 3.8c1.3 0 2.6.5 3.6 1.4.1.1.3.1.4 0l1.2-1.2c.1-.1.1-.3 0-.4-1.4-1.3-3.2-2-5.2-2s-3.8.7-5.2 2c-.1.1-.1.3 0 .4l1.2 1.2c.1.1.3.1.4 0 1-.9 2.3-1.4 3.6-1.4Zm2.3 2.6c.1-.1.1-.3 0-.4-.6-.6-1.4-.9-2.3-.9s-1.7.3-2.3.9c-.1.1-.1.3 0 .4l2.1 2.1c.1.1.3.1.4 0l2.1-2.1Z"/></svg>`;
  const battery = `<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.8" fill="none" stroke="${color}" stroke-opacity=".4"/><rect x="2" y="2" width="20" height="9" rx="2.5" fill="${color}"/><path d="M25 4.5v4c.8-.3 1.4-1.1 1.4-2s-.6-1.7-1.4-2Z" fill="${color}" fill-opacity=".45"/></svg>`;
  if (kind === 'tablet') {
    return `<div class="statusbar tablet" style="color:${color}">
      <span>9:41&nbsp;&nbsp;Fri Oct 2</span><span class="sb-icons">${wifi}<span style="font-size:12px">100%</span>${battery}</span></div>`;
  }
  return `<div class="statusbar phone" style="color:${color}">
    <span class="sb-time">9:41</span><span class="sb-icons">${signal}${wifi}${battery}</span></div>`;
}

function settingsForm() {
  const stepper = `<div class="stepper"><span>−</span><i></i><span>+</span></div>`;
  const toggle = `<div class="toggle"><div></div></div>`;
  const row = (inner, extra = '') => `<div class="form-row${extra}">${inner}</div>`;
  const labelRow = (ic, text, color = '#fff') => `<span class="form-label">${icon(ic, 21, YELLOW)}<span style="color:${color}">${text}</span></span>`;
  return `
    <div class="form-header">Timer</div>
    <div class="form-section">
      ${row(`<span>Minutes</span><span class="form-value">7</span>${stepper}`)}
      ${row(`<span>Seconds</span><span class="form-value">30</span>${stepper}`)}
      ${row(labelRow('reset', 'Reset to Selected Time', YELLOW))}
    </div>
    <div class="form-header">Stage Display</div>
    <div class="form-section">
      ${row(`${labelRow('bubble', 'Comic Final-Minute Mode')}${toggle}`)}
      ${row(`${labelRow('headphones', 'Show Bluetooth Help on Timer')}${toggle}`)}
    </div>
    <div class="form-header">Bluetooth Headphones</div>
    <div class="form-section">
      ${row(labelRow('gear', 'Pair headphones in the iOS Settings app.'), ' multi')}
      ${row(labelRow('playPause', 'Use the play/pause button to start or stop the timer.'), ' multi')}
      ${row(labelRow('eye', 'Keep this app open so the performer can see the countdown.'), ' multi')}
    </div>
    <div class="form-section" style="margin-top:28px">
      ${row(labelRow('question', 'Open Full Tutorial', YELLOW))}
    </div>`;
}

function settingsSheet(kind, w, h) {
  const nav = `
    <div class="sheet-nav"><div class="glass-done">Done</div></div>
    <div class="sheet-title">Settings</div>`;
  if (kind === 'tablet') {
    const sw = 700, sh = 740;
    return `<div class="dim" style="background:rgba(0,0,0,.5)"></div>
      <div class="sheet" style="left:${(w - sw) / 2}px;top:${(h - sh) / 2}px;width:${sw}px;height:${sh}px;border-radius:38px">${nav}<div class="form">${settingsForm()}</div></div>`;
  }
  // Medium detent: roughly half the screen, floating with a small inset (iOS 26 sheets).
  const inset = 7, sh = Math.round(h * 0.52);
  return `<div class="dim" style="background:rgba(0,0,0,.2)"></div>
    <div class="sheet" style="left:${inset}px;right:${inset}px;bottom:${inset}px;height:${sh}px;border-radius:46px">
      <div class="grabber"></div>${nav}<div class="form">${settingsForm()}</div></div>`;
}

// Full device screen: background, status bar, the GeometryReader area, home indicator and optional sheet.
// opts: { w, h, platform: 'ios'|'mac', chrome: 'phone'|'tablet'|null, insets: {top,left,right}, state, sheet }
function appScreen(opts) {
  const { w, h, platform = 'ios', chrome = null, insets = { top: 0, left: 0, right: 0 }, state = {}, sheet = null } = opts;
  const gw = w - insets.left - insets.right;
  const gh = h - insets.top;  // the stage ignores the bottom safe area
  const L = stageLayout(gw, gh, platform);
  const m = timerModel(state);
  const bg = m.isFinal
    ? `<div class="bg" style="background:${YELLOW}"><div class="bg-fade" style="height:100%;background:linear-gradient(transparent, rgba(0,0,0,.18))"></div></div>`
    : `<div class="bg" style="background:#000"><div class="bg-fade" style="height:420px;background:linear-gradient(transparent, rgb(23,28,31))"></div></div>`;
  const content = `
    <div class="stage-col" style="gap:${L.verticalSpacing}px;${L.contentMaxWidth ? `max-width:${L.contentMaxWidth}px;` : ''}">
      ${headerStrip(L, m)}
      ${timerDisplay(L, m)}
      ${progressBar(L, m)}
      ${bottomPanel(L, m)}
    </div>`;
  const showStatusBar = chrome === 'tablet' || (chrome === 'phone' && h > w);
  return `
  <div class="app-screen" style="width:${w}px;height:${h}px">
    ${bg}
    ${showStatusBar ? statusBar(chrome, w) : ''}
    <div class="geometry" style="left:${insets.left}px;top:${insets.top}px;width:${gw}px;height:${gh}px">${content}</div>
    ${chrome ? `<div class="home-indicator" style="background:${m.isFinal ? 'rgba(0,0,0,.85)' : 'rgba(255,255,255,.85)'}"></div>` : ''}
    ${sheet === 'settings' ? settingsSheet(chrome, w, h) : ''}
  </div>`;
}

// Mimics Text.minimumScaleFactor/lineLimit(1): shrink to fit, then truncate.
function fitAppText(root) {
  root.querySelectorAll('.fit-timer').forEach((el) => {
    const base = parseFloat(el.dataset.size);
    el.style.fontSize = base + 'px';
    const box = el.closest('.timer-box');
    const stack = el.parentElement;
    const availW = box.clientWidth - parseFloat(getComputedStyle(box).paddingLeft) * 2;
    const sub = stack.querySelector('.timer-sub');
    const subH = sub ? sub.offsetHeight + parseFloat(getComputedStyle(stack).gap) : 0;
    const availH = box.clientHeight - subH;
    const scale = Math.max(0.28, Math.min(1, availW / el.scrollWidth, availH / el.offsetHeight));
    el.style.fontSize = base * scale + 'px';
  });
  const shrink = (el, minScale) => {
    const base = parseFloat(getComputedStyle(el).fontSize);
    for (let s = 1; s >= minScale && el.scrollWidth > el.clientWidth + 0.5; s -= 0.02) {
      el.style.fontSize = base * s + 'px';
    }
  };
  // Header: the Bluetooth hint gives way first, then the status badge shrinks to its 0.75 minimum scale.
  root.querySelectorAll('.header').forEach((header) => {
    const badge = header.querySelector('.fit-badge');
    const hint = header.querySelector('.fit-hint');
    const last = header.lastElementChild;
    const overflowing = () =>
      last.offsetLeft + last.offsetWidth > header.clientWidth - parseFloat(getComputedStyle(header).paddingRight) + 0.5;
    if (hint) {
      shrink(hint, 0.7);
      if (hint.clientWidth < 24) hint.style.visibility = 'hidden';  // nothing legible left, not even "…"
    }
    const base = parseFloat(getComputedStyle(badge).fontSize);
    for (let s = 1; s >= 0.75 && overflowing(); s -= 0.02) badge.style.fontSize = base * s + 'px';
    if (overflowing()) badge.style.flexShrink = '1';
  });
}
