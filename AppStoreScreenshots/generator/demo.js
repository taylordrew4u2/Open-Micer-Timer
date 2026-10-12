#!/usr/bin/env node
// Renders the README demo: ../../docs/media/demo.mp4 and demo.gif (needs ffmpeg).
//   node demo.js

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');

const FPS = 10;
const outDir = path.resolve(__dirname, '../../docs/media');

// [state, caption, seconds on screen]
function timeline() {
  const t = [];
  const hold = (state, caption, secs) => t.push([state, caption, secs]);
  hold({ total: 300, remaining: 300 }, 'Set ready. <em>5:00</em>', 1.5);
  hold({ total: 300, remaining: 300, running: true }, 'Tap play on your <em>headphones.</em>', 1);
  // Fast-forward the set: 5:00 -> 1:01
  for (let r = 299; r > 61; r -= 7) hold({ total: 300, remaining: r, running: true }, 'Counting down…', 0.1);
  hold({ total: 300, remaining: 61, running: true }, 'Counting down…', 0.6);
  hold({ total: 300, remaining: 60, running: true }, 'Final minute: <em>screen goes yellow.</em>', 1.4);
  for (let r = 59; r >= 1; r -= r > 10 ? 3 : 1) hold({ total: 300, remaining: r, running: true }, 'Final minute: <em>screen goes yellow.</em>', r > 10 ? 0.15 : 0.3);
  hold({ total: 300, remaining: 0 }, 'Time’s up. <em>Everyone knows.</em>', 2.5);
  return t;
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const frames = fs.mkdtempSync(path.join(os.tmpdir(), 'omt-demo-'));
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 420, height: 720 }, deviceScaleFactor: 2 });
  await page.goto(pathToFileURL(path.join(__dirname, 'demo.html')).href);
  await page.waitForFunction(() => window.__ready);
  let n = 0;
  for (const [state, caption, secs] of timeline()) {
    await page.evaluate((a) => window.drawFrame(a), { state, caption });
    const shot = path.join(frames, 'shot.png');
    await page.screenshot({ path: shot });
    for (let i = 0; i < Math.max(1, Math.round(secs * FPS)); i++) {
      fs.copyFileSync(shot, path.join(frames, `f${String(n++).padStart(5, '0')}.png`));
    }
  }
  await browser.close();
  const input = ['-y', '-framerate', String(FPS), '-i', path.join(frames, 'f%05d.png')];
  execFileSync('ffmpeg', [...input, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-movflags', '+faststart',
    path.join(outDir, 'demo.mp4')], { stdio: 'inherit' });
  execFileSync('ffmpeg', [...input, '-vf', 'scale=420:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=none',
    path.join(outDir, 'demo.gif')], { stdio: 'inherit' });
  fs.rmSync(frames, { recursive: true });
  console.log(`Wrote ${outDir}/demo.mp4 and demo.gif`);
})();
