// web_shots.mjs loads a built screensaver page in headless Chromium and saves
// screenshots of it at a few times after its first painted frame, so a run can
// be seen playing. It exits non-zero on a console error, an exception, a
// failed request or a canvas that never paints. A moving page must also start
// still on its first frame under the runner's warming-up indicator, keep that
// frame until its ride starts, and have dropped the indicator by every shot.
// It prints what the page's skin put under the canvas, the keyboard help and
// the links, for the gate to hold to the skin.
// The runner's own console lines (`?timing=1`) are printed as they come.
//
//   node tools/web_shots.mjs <page url> <shots folder> <ms after first paint>...
//   node tools/web_shots.mjs <page url> <shots folder> step=<N>...
//
// A `step=N` shot loads the page at `?step=N`, which stops on the frame after
// N steps, and saves the canvas alone at its own size as step-NNN.png, the
// name `zig build png -- <dir> N` gives the native frame at that step.
//
// There is no Playwright package on the box, so this speaks the browser's
// DevTools protocol over the WebSocket that Node has built in, as roc-apps'
// canvas_apps/safari/tutorial/book_check.mjs does.
import { spawn } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const CHROME = `${process.env.HOME}/.cache/ms-playwright/chromium-1140/chrome-linux/chrome`;
const [url, shots, ...times] = process.argv.slice(2);
if (!url || !shots || times.length === 0) { console.error("usage: web_shots.mjs <page url> <shots folder> <ms>..."); process.exit(2); }
mkdirSync(shots, { recursive: true });

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
const failures = [];

function startBrowser(profile) {
  const browser = spawn(CHROME, [
    "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars", "--mute-audio",
    "--remote-debugging-port=0", `--user-data-dir=${profile}`, "--window-size=1000,700", "about:blank",
  ], { stdio: ["ignore", "ignore", "pipe"] });
  const address = new Promise((found, refused) => {
    let said = "";
    browser.stderr.on("data", (chunk) => {
      said += chunk;
      const seen = said.match(/DevTools listening on (ws:\S+)/);
      if (seen) found(seen[1]);
    });
    browser.on("error", refused);
    browser.on("exit", (code) => refused(new Error(`chromium exited ${code}: ${said}`)));
  });
  return { browser, address };
}

async function connect(address) {
  const socket = new WebSocket(address);
  await new Promise((open, refused) => { socket.onopen = open; socket.onerror = () => refused(new Error("no DevTools socket")); });
  let lastId = 0;
  const waiting = new Map();
  const hearers = new Map();
  socket.onmessage = ({ data }) => {
    const message = JSON.parse(data);
    if (message.id) {
      const { answer, refuse } = waiting.get(message.id);
      waiting.delete(message.id);
      message.error ? refuse(new Error(JSON.stringify(message.error))) : answer(message.result);
    } else {
      hearers.get(message.method)?.(message.params);
    }
  };
  return {
    socket,
    on: (method, hear) => hearers.set(method, hear),
    send: (method, params = {}, sessionId) => new Promise((answer, refuse) => {
      const id = ++lastId;
      waiting.set(id, { answer, refuse });
      socket.send(JSON.stringify({ id, method, params, sessionId }));
    }),
  };
}

// Waits until the page's canvas holds more than a few colours, which is a
// painted frame rather than the loading text, and answers how long that took.
const FIRST_PAINT = `(async () => {
  const started = performance.now();
  while (performance.now() - started < 20000) {
    const canvas = document.querySelector('canvas');
    if (canvas && canvas.width > 0) {
      const { data } = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height);
      const colours = new Set();
      for (let at = 0; at < data.length; at += 4 * 97) colours.add((data[at] << 16) | (data[at + 1] << 8) | data[at + 2]);
      if (colours.size > 3) return { painted: performance.now(), colours: colours.size };
    }
    await new Promise((later) => setTimeout(later, 20));
  }
  return { missing: true };
})()`;

// A hash of every 13th pixel of the page's canvas, defined on the page.
const CANVAS_HASH = `window.__canvasHash = () => {
  const canvas = document.querySelector('canvas');
  const { data } = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height);
  let hash = 0;
  for (let at = 0; at < data.length; at += 4 * 13) hash = (hash * 31 + data[at] + (data[at + 1] << 8) + (data[at + 2] << 16)) | 0;
  return hash;
}; window.__canvasHash()`;

// Watches the start of a moving page, from its first painted frame: the
// warming-up indicator must be over it, and the canvas must hold the first
// frame (`?step=0`'s, whose hash is `first`), sampled every 15 ms, until the
// page says the ride has started. The first frame is the still page's rather
// than this one's, since by the first sample the warm-up has been running for
// a while and could already have changed the canvas. Then it waits for the
// ride's first drawn frame and answers its hash with the steps it shows
// (`data-steps`), read in one turn of the page, so the two agree.
const warmUpWatch = (first) => `(async () => {
  const canvas = document.querySelector('canvas');
  const sample = window.__canvasHash;
  const indicator = document.getElementById('warming-indicator') !== null;
  const phaseAtFirst = canvas.dataset.phase ?? 'none';
  const started = performance.now();
  let samples = 0;
  let changed = 0;
  const seen = [];
  while (canvas.dataset.phase === 'warming' && performance.now() - started < 5000) {
    const now = sample();
    if (now !== ${first}) { changed++; seen.push(now); }
    samples++;
    await new Promise((later) => setTimeout(later, 15));
  }
  const ms = performance.now() - started;
  let ride = null;
  while (ride === null && performance.now() - started < 8000) {
    if (canvas.dataset.steps !== undefined) ride = { hash: sample(), steps: Number(canvas.dataset.steps) };
    else await new Promise((later) => setTimeout(later, 4));
  }
  return { indicator, phaseAtFirst, samples, changed, seen, ride, phase: canvas.dataset.phase ?? 'none', ms };
})()`;

// The page's address with `?step=N` added to whatever query it has (`?timing=1`).
function atStep(step) {
  const address = new URL(url);
  address.searchParams.set("step", String(step));
  return address.href;
}

const INDICATOR_UP = "document.getElementById('warming-indicator') !== null";

// What the page's skin put under the canvas: the keyboard help's text and each
// link's words and address, as the reader sees them.
const SKIN_SEEN = `(() => {
  const help = document.getElementById('keyboard-help');
  const links = [...document.querySelectorAll('#skin-links a')].map((a) => a.textContent + ' ' + a.getAttribute('href'));
  return { help: help ? help.textContent : null, links };
})()`;

async function evaluate(page, expression) {
  const { result, exceptionDetails } = await page.send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true }, page.session);
  if (exceptionDetails) throw new Error(exceptionDetails.exception?.description ?? exceptionDetails.text);
  return result.value;
}

const profile = mkdtempSync(join(tmpdir(), "web-shots-"));
const { browser, address } = startBrowser(profile);
let exitCode = 1;
try {
  const link = await connect(await address);
  const { targetId } = await link.send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await link.send("Target.attachToTarget", { targetId, flatten: true });
  const page = { send: link.send, session: sessionId };
  link.on("Runtime.exceptionThrown", ({ exceptionDetails }) => failures.push(`exception: ${exceptionDetails.exception?.description ?? exceptionDetails.text}`));
  link.on("Runtime.consoleAPICalled", ({ type, args }) => {
    if (type === "error" || type === "warning") failures.push(`console ${type}: ${args.map((a) => a.value ?? a.description).join(" ")}`);
    if (type === "log" && String(args[0]?.value).startsWith("canvas_app_runner:")) console.log(args[0].value);
  });
  link.on("Network.responseReceived", ({ response }) => { if (response.status >= 400) failures.push(`${response.status} for ${response.url}`); });
  link.on("Network.loadingFailed", ({ canceled, errorText }) => { if (!canceled) failures.push(`a request failed: ${errorText}`); });
  for (const domain of ["Page", "Runtime", "Network"]) await page.send(`${domain}.enable`, {}, page.session);
  // 700 high, so a 600-high canvas within the runner's 88vh is drawn at its own size.
  await page.send("Emulation.setDeviceMetricsOverride", { width: 1000, height: 700, deviceScaleFactor: 1, mobile: false }, page.session);
  const steps = times.filter((t) => t.startsWith("step="));
  for (const step of steps.map((t) => Number(t.slice(5)))) {
    const shown = new Promise((done) => link.on("Page.loadEventFired", done));
    await page.send("Page.navigate", { url: atStep(step) }, page.session);
    await shown;
    const still = await evaluate(page, FIRST_PAINT);
    if (still.missing) { failures.push(`step ${step}: the canvas never painted`); continue; }
    const box = await evaluate(page, "(() => { const r = document.querySelector('canvas').getBoundingClientRect(); return { x: r.left, y: r.top, width: r.width, height: r.height }; })()");
    const { data } = await page.send("Page.captureScreenshot", { format: "png", clip: { ...box, scale: 1 } }, page.session);
    const path = join(shots, `step-${String(step).padStart(3, "0")}.png`);
    writeFileSync(path, Buffer.from(data, "base64"));
    console.log(`shot ${path}, the canvas ${box.width} by ${box.height}`);
  }
  const moving = steps.length < times.length;
  let firstFrame = null;
  let rideFrame = null;
  if (moving) {
    const still = new Promise((done) => link.on("Page.loadEventFired", done));
    await page.send("Page.navigate", { url: atStep(0) }, page.session);
    await still;
    if ((await evaluate(page, FIRST_PAINT)).missing) failures.push("step 0: the canvas never painted");
    else firstFrame = await evaluate(page, CANVAS_HASH);
  }
  const loaded = new Promise((done) => link.on("Page.loadEventFired", done));
  await page.send("Page.navigate", { url }, page.session);
  await loaded;
  const first = moving ? await evaluate(page, FIRST_PAINT) : { skipped: true };
  if (first.skipped) {
    // Only stills were asked for.
  } else if (first.missing) {
    failures.push("the canvas never painted a frame");
  } else {
    const navStart = await evaluate(page, "performance.timeOrigin + 0");
    console.log(`first painted frame ${Math.round(first.painted)} ms after navigation, ${first.colours} colours sampled (origin ${Math.round(navStart)})`);
    const shotStart = Date.now();
    const atFirstPaint = await evaluate(page, CANVAS_HASH);
    const warm = await evaluate(page, warmUpWatch(firstFrame));
    if (atFirstPaint !== firstFrame) { warm.changed++; }
    warm.samples++;
    console.log(
      `warm-up: indicator ${warm.indicator ? "over" : "missing from"} the first frame, phase ${warm.phaseAtFirst}; ` +
        `the canvas changed in ${warm.changed} of ${warm.samples} samples; phase ${warm.phase} after ${Math.round(warm.ms)} ms`,
    );
    if (!warm.indicator || warm.phaseAtFirst !== "warming") failures.push("the first frame was not shown warming up under its indicator");
    if (warm.changed > 0) failures.push(`the canvas changed during the warm-up, in ${warm.changed} of ${warm.samples} samples`);
    if (warm.phase !== "riding") failures.push(`the ride never started: phase ${warm.phase} after ${Math.round(warm.ms)} ms`);
    if (warm.changed > 0) console.log(`warm-up: first frame ${firstFrame}, seen ${warm.seen.join(" ")}`);
    if (warm.ride === null) failures.push("the ride never drew a frame");
    else rideFrame = warm.ride;
    // The gate holds these lines to the skin the page was built with.
    const skin = await evaluate(page, SKIN_SEEN);
    console.log(`skin help: ${skin.help === null ? "none" : skin.help}`);
    console.log(`skin links: ${skin.links.length ? skin.links.join(", ") : "none"}`);
    for (const at of times.filter((t) => !t.startsWith("step=")).map(Number)) {
      const wait = at - (Date.now() - shotStart);
      if (wait > 0) await sleep(wait);
      // A shot with the indicator in it differs from one without, so two
      // shots could differ on a page that never moved.
      if (await evaluate(page, INDICATOR_UP)) failures.push(`the warming-up indicator is still up at ${at} ms`);
      const { data } = await page.send("Page.captureScreenshot", { format: "png" }, page.session);
      const path = join(shots, `at_${String(at).padStart(5, "0")}ms.png`);
      writeFileSync(path, Buffer.from(data, "base64"));
      console.log(`shot ${path} at ${Date.now() - shotStart} ms after first paint`);
    }
  }
  // The ride's first frame must be the still page's at the same step, which it
  // is only when the warm-up left the model where the still frame showed it.
  if (rideFrame !== null) {
    const still = new Promise((done) => link.on("Page.loadEventFired", done));
    await page.send("Page.navigate", { url: atStep(rideFrame.steps) }, page.session);
    await still;
    const painted = await evaluate(page, FIRST_PAINT);
    const expected = painted.missing ? null : await evaluate(page, CANVAS_HASH);
    const same = expected === rideFrame.hash;
    console.log(`ride: its first frame, after ${rideFrame.steps} steps, is ${same ? "" : "not "}the still page's at that step`);
    if (!same) failures.push(`the ride's first frame, after ${rideFrame.steps} steps, is not ?step=${rideFrame.steps}'s`);
  }
  for (const failure of failures) console.log(`FAIL ${failure}`);
  exitCode = failures.length ? 1 : 0;
  link.socket.close();
} finally {
  browser.removeAllListeners("exit");
  browser.kill("SIGKILL");
  await sleep(300);
  rmSync(profile, { recursive: true, force: true });
}
process.exit(exitCode);
