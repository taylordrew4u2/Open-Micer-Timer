#!/usr/bin/env node
// Renders every App Store screenshot set into ../<canvas>/<slide>.png and a contact sheet at ../preview.png.
//
//   npm install && npm run render            # all sets
//   node render.js iPhone-6.5_1284x2778 iPad-13_2064x2752        # only some sets
//
// To use real simulator captures instead of the HTML replica, drop PNGs at
// real/<canvas>/<slide>.png (same names as the output files); they are placed inside the device frame.

const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const { chromium } = require('playwright');

const CANVASES = {
  'iPhone-6.5_1284x2778': { w: 428, h: 926, scale: 3 },
  'iPhone-6.5_1242x2688': { w: 414, h: 896, scale: 3 },
  'iPhone-6.9_1320x2868': { w: 440, h: 956, scale: 3 },
  'iPad-13_2064x2752': { w: 1032, h: 1376, scale: 2 },
  'Mac_2880x1800': { w: 1440, h: 900, scale: 2 },
};

const here = __dirname;
const outRoot = path.resolve(here, '..');
const stageUrl = pathToFileURL(path.join(here, 'stage.html')).href;

async function renderSlide(context, canvas, slide) {
  const page = await context.newPage();
  const url = new URL(stageUrl);
  url.searchParams.set('canvas', canvas);
  url.searchParams.set('slide', slide);
  const real = path.join(here, 'real', canvas, `${slide}.png`);
  if (fs.existsSync(real)) url.searchParams.set('real', pathToFileURL(real).href);
  await page.goto(url.href);
  await page.waitForFunction(() => window.__ready || window.__error, null, { timeout: 30000 });
  const error = await page.evaluate(() => window.__error);
  if (error) throw new Error(`${canvas}/${slide}: ${error}`);
  await page.evaluate(() => Promise.all([...document.images].map((img) => img.decode().catch(() => null))));
  const file = path.join(outRoot, canvas, `${slide}.png`);
  await page.screenshot({ path: file });
  await page.close();
  return file;
}

async function contactSheet(browser, files) {
  const rows = Object.entries(files).map(([canvas, list]) => `
    <section><h2>${canvas.replace('_', ' <small>')}</small></h2>
    <div class="row ${canvas.startsWith('Mac') ? 'mac' : ''}">${list.map((f) => `<img src="${pathToFileURL(f).href}">`).join('')}</div></section>`).join('');
  const html = `<!doctype html><meta charset="utf-8"><style>
    body { margin: 0; padding: 40px; background: #16171a; font: 600 22px Inter, system-ui, sans-serif; color: #fff; width: 2400px; }
    h2 { margin: 30px 0 16px; font-size: 26px; } small { color: #8a8d93; font-weight: 500; font-size: 18px; margin-left: 10px; }
    .row { display: flex; gap: 18px; } .row img { height: 620px; border-radius: 14px; } .row.mac img { height: 340px; }
  </style>${rows}`;
  const page = await browser.newPage({ viewport: { width: 2480, height: 800 }, deviceScaleFactor: 1 });
  // Loaded from a file (not setContent) so the file:// screenshots are allowed to load.
  const tmp = path.join(require('os').tmpdir(), `screenshot-preview-${process.pid}.html`);
  fs.writeFileSync(tmp, html);
  await page.goto(pathToFileURL(tmp).href, { waitUntil: 'load' });
  const broken = await page.evaluate(() => [...document.images].filter((img) => !img.naturalWidth).map((img) => img.src));
  if (broken.length) throw new Error(`Preview could not load: ${broken.join(', ')}`);
  await page.screenshot({ path: path.join(outRoot, 'preview.png'), fullPage: true });
  await page.close();
  fs.unlinkSync(tmp);
}

(async () => {
  const wanted = process.argv.slice(2);
  const canvases = wanted.length ? wanted : Object.keys(CANVASES);
  const browser = await chromium.launch();
  const files = {};
  for (const canvas of canvases) {
    const c = CANVASES[canvas];
    if (!c) throw new Error(`Unknown canvas ${canvas}. Options: ${Object.keys(CANVASES).join(', ')}`);
    fs.mkdirSync(path.join(outRoot, canvas), { recursive: true });
    const context = await browser.newContext({ viewport: { width: c.w, height: c.h }, deviceScaleFactor: c.scale });
    const probe = await context.newPage();
    await probe.goto(stageUrl);
    await probe.waitForFunction(() => typeof slideIds === 'function');
    const slides = await probe.evaluate((name) => slideIds(name), canvas);
    await probe.close();
    files[canvas] = [];
    for (const slide of slides) {
      const file = await renderSlide(context, canvas, slide);
      files[canvas].push(file);
      console.log(`✓ ${path.relative(outRoot, file)}`);
    }
    await context.close();
  }
  if (!wanted.length) await contactSheet(browser, files);
  await browser.close();
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
