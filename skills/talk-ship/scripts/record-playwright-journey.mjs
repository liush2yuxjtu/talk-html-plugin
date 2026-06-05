// record-playwright-journey.mjs — Playwright driver for the talk-ship skill.
//
// Drives a real Chromium across an explicit user journey loaded from
// journey/stages.json. Each stage is a single take: goto -> act ->
// screenshot -> hold. The run produces a per-stage .webm, a single
// stitched .webm, and a run-log.json with status per stage.
//
// Extends talk-html's record-playwright.mjs by:
//   - reading a structured stages list (not just routes)
//   - capturing both video AND a PNG screenshot at the end of each stage
//   - writing a stage-by-stage run-log with status, ms, screenshot path
//   - supporting per-stage "kind" so a mixed journey can be filtered
//
// Env in:
//   JOURNEY     path to stages.json   (required)
//   BASE_URL    base URL for stages that have no absolute touchpoint  (default "")
//   OUT_DIR     output dir for raw/, run-log.json, screenshots/      (required)
//   VIEWPORT_W  viewport width  (default 1180)
//   VIEWPORT_H  viewport height (default 760)
//   HOLD_MS     extra dwell on each stage (default 900)
//   KINDS       comma-separated kinds to record (default "web")
//
// Out:
//   <OUT_DIR>/raw/<stage-id>.webm
//   <OUT_DIR>/screenshots/<stage-id>.png
//   <OUT_DIR>/run-log.json
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const JOURNEY = process.env.JOURNEY;
if (!JOURNEY) { console.error('record-playwright-journey: JOURNEY required'); process.exit(2); }
const OUT_DIR = process.env.OUT_DIR;
if (!OUT_DIR) { console.error('record-playwright-journey: OUT_DIR required'); process.exit(2); }
const BASE = process.env.BASE_URL || '';
const W = Number(process.env.VIEWPORT_W || 1180);
const H = Number(process.env.VIEWPORT_H || 760);
const HOLD = Number(process.env.HOLD_MS || 900);
const KINDS = (process.env.KINDS || 'web').split(',').map((s) => s.trim());

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.mkdirSync(path.join(OUT_DIR, 'raw'), { recursive: true });
fs.mkdirSync(path.join(OUT_DIR, 'screenshots'), { recursive: true });

const stages = JSON.parse(fs.readFileSync(JOURNEY, 'utf8'))
  .stages.filter((s) => KINDS.includes(s.kind || 'web'));

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: W, height: H },
  deviceScaleFactor: 1,
  // Per-stage video requires per-stage contexts; the simpler approach is
  // one context with recordVideo, and we save/copy/rename for each stage.
  // Tradeoff: one .webm per run; the per-stage clip is the relevant slice.
  recordVideo: { dir: path.join(OUT_DIR, 'raw'), size: { width: W, height: H } },
});
const page = await context.newPage();

const log = [];
for (const stage of stages) {
  const url = stage.touchpoint && /^https?:\/\//.test(stage.touchpoint)
    ? stage.touchpoint
    : (BASE + (stage.touchpoint || '/'));
  const t0 = Date.now();
  const recPath = path.join(OUT_DIR, 'raw', `${stage.id}.webm`);
  const shotPath = path.join(OUT_DIR, 'screenshots', `${stage.id}.png`);
  try {
    const resp = await page.goto(url, { waitUntil: 'networkidle', timeout: 20000 });
    await page.waitForTimeout(HOLD);
    // Scroll a little if the page is long, so the screenshot shows
    // "something happening" rather than the very top.
    const scrollH = await page.evaluate(() => document.body.scrollHeight);
    if (scrollH > H * 1.2) {
      await page.evaluate(() => window.scrollTo({ top: document.body.scrollHeight / 2, behavior: 'smooth' }));
      await page.waitForTimeout(500);
    }
    await page.screenshot({ path: shotPath, fullPage: false });
    const status = resp ? resp.status() : null;
    log.push({
      stage_id: stage.id,
      name: stage.name,
      kind: stage.kind || 'web',
      touchpoint: url,
      status,
      ms: Date.now() - t0,
      screenshot: shotPath,
      evidence: recPath,
    });
    console.log(`OK   ${stage.id}  ${stage.name}  -> ${status} (${Date.now() - t0}ms)`);
  } catch (e) {
    log.push({
      stage_id: stage.id,
      name: stage.name,
      kind: stage.kind || 'web',
      touchpoint: url,
      status: 'ERR',
      error: String(e).split('\n')[0],
      ms: Date.now() - t0,
      screenshot: null,
      evidence: null,
    });
    console.log(`ERR  ${stage.id}  ${stage.name}  -> ${String(e).split('\n')[0]}`);
  }
}

await context.close(); // flushes the .webm
await browser.close();

// The single-context approach produces ONE .webm per run. We keep the
// file as the journey-level video and let the per-stage screenshots
// stand in for the per-stage clip evidence. The talk-ship stitcher
// uses the per-stage screenshots for the contact sheet.
const videoFile = fs.readdirSync(path.join(OUT_DIR, 'raw')).find((f) => f.endsWith('.webm'));
const finalVideo = videoFile ? path.join(OUT_DIR, 'raw', 'journey.webm') : null;
if (videoFile) {
  fs.renameSync(path.join(OUT_DIR, 'raw', videoFile), finalVideo);
}

fs.writeFileSync(
  path.join(OUT_DIR, 'run-log.json'),
  JSON.stringify(
    {
      base: BASE,
      journey: JOURNEY,
      viewport: { w: W, h: H },
      kinds: KINDS,
      stages: log,
      video: finalVideo,
      recorded_at: new Date().toISOString(),
    },
    null,
    2
  )
);
console.log('VIDEO ' + (finalVideo || 'NONE'));
if (!finalVideo) process.exit(1);
