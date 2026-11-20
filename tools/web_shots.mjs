// web_shots.mjs loads a built screensaver page in headless Chromium and saves
// screenshots of it at a few times after its ride starts, so a run can be
// seen playing. It exits non-zero on a console error, an exception, a failed
// request or a canvas that never paints. A moving page must also start still
// on its first frame under the runner's warming-up indicator, keep that frame
// until its ride starts, and have dropped the indicator by every shot. It is
// loaded with `?hold=1`, so its start waits at each edge of the warm-up until
// this has looked there, and a short warm-up is never missed.
// It prints what the page's skin put under the canvas, the keyboard help and
// the links, for the gate to hold to the skin. A page with a code pane
// (Lanterns', web/lanterns_platform/code_pane.js) is loaded at step 0 at
// 1440 by 900, where the pane must stand beside the canvas, as tall as it,
// showing a module, and at 1000 by 700, where it must be hidden; it prints the
// file the pane's strip names, or `code pane: none` for a page without one.
// The runner's own console lines (`?timing=1`) are printed as they come.
//
//   node tools/web_shots.mjs <page url> <shots folder> <ms after the ride starts>...
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

// Watches the start of a moving page loaded with `?hold=1`, which waits at
// each edge of its warm-up, naming the edge in `data-held`, until this lets it
// go on. So the check sees both edges for certain, however short the warm-up:
// at each, the warming-up indicator must be over the canvas, the phase must
// be `warming`, and the canvas must hold the first frame (`?step=0`'s, whose
// hash is `first`). Between them it samples the canvas every 15 ms as well.
// Then it waits for the ride's first drawn frame and answers its hash with
// the steps it shows (`data-steps`), read in one turn of the page, so the two
// agree.
const warmUpWatch = (first) => `(async () => {
  const canvas = document.querySelector('canvas');
  const sample = window.__canvasHash;
  const pause = (ms) => new Promise((later) => setTimeout(later, ms));
  const started = performance.now();
  const heldAt = async (edge) => {
    while (canvas.dataset.held !== edge) {
      if (performance.now() - started > 8000) return null;
      await pause(4);
    }
    const hash = sample();
    return {
      indicator: document.getElementById('warming-indicator') !== null,
      phase: canvas.dataset.phase ?? 'none',
      hash,
      same: hash === ${first},
    };
  };
  const before = await heldAt('before-warm-up');
  if (before === null) return { unheld: 'before the warm-up' };
  const warmStart = performance.now();
  window.canvasAppGoOn();
  let samples = 0;
  let changed = 0;
  const seen = [];
  while (canvas.dataset.held !== 'after-warm-up' && performance.now() - started < 8000) {
    const now = sample();
    if (now !== ${first}) { changed++; seen.push(now); }
    samples++;
    await pause(15);
  }
  const after = await heldAt('after-warm-up');
  if (after === null) return { unheld: 'after the warm-up' };
  const ms = performance.now() - warmStart;
  window.canvasAppGoOn();
  let ride = null;
  while (ride === null && performance.now() - started < 8000) {
    if (canvas.dataset.steps !== undefined) ride = { hash: sample(), steps: Number(canvas.dataset.steps) };
    else await pause(4);
  }
  return { before, after, samples, changed, seen, ride, phase: canvas.dataset.phase ?? 'none', ms };
})()`;

// The page's address with `?step=N` added to whatever query it has (`?timing=1`).
function atStep(step) {
  const address = new URL(url);
  address.searchParams.set("step", String(step));
  return address.href;
}

// The page's address with `?hold=1` added, so its start waits at each edge of
// the warm-up for `warmUpWatch` (canvas_app_runner.js's `holdAt`).
function held(page) {
  const address = new URL(page);
  address.searchParams.set("hold", "1");
  return address.href;
}

const INDICATOR_UP = "document.getElementById('warming-indicator') !== null";

// Runs in each page before its own scripts, and notes whether the warming-up
// indicator went up while there was no canvas yet: the start then shows the
// pill through the wasm's download and compile rather than a bare loading page.
const PILL_BEFORE_CANVAS = `new MutationObserver((changes, watcher) => {
  if (document.getElementById('warming-indicator') === null) return;
  window.__pillBeforeCanvas = document.querySelector('canvas') === null;
  watcher.disconnect();
}).observe(document, { childList: true, subtree: true });`;

// What the page's skin put under the canvas: the keyboard help's text and each
// link's words, address and where it opens, as the reader meets them.
const SKIN_SEEN = `(() => {
  const help = document.getElementById('keyboard-help');
  const links = [...document.querySelectorAll('#skin-links a')].map((a) => a.textContent + ' ' + a.getAttribute('href') + (a.getAttribute('target') === '_blank' ? ' in a new tab' : ' in this tab'));
  return { help: help ? help.textContent : null, links };
})()`;

// The code pane at step 0, once its code is in: whether it is shown, whether
// it stands right of the canvas and as tall, and the file its strip names.
const PANE_SEEN = `(async () => {
  if (!window.SHOW.pane) return { none: true };
  const started = performance.now();
  let pre = null;
  while (performance.now() - started < 5000) {
    pre = document.querySelector('#code-pane pre');
    if (pre && pre.textContent !== '') break;
    await new Promise((later) => setTimeout(later, 20));
  }
  const pane = document.getElementById('code-pane');
  if (!pane || !pre || pre.textContent === '') return { empty: true };
  const box = pane.getBoundingClientRect();
  const canvas = document.querySelector('canvas').getBoundingClientRect();
  return {
    shown: getComputedStyle(pane).display !== 'none' && box.width > 0,
    beside: box.left >= canvas.right && Math.abs(box.height - canvas.height) < 2 && Math.abs(box.top - canvas.top) < 2,
    first: document.getElementById('code-file').textContent,
  };
})()`;

// Loads the page at step 0 at `width` by `height` and answers PANE_SEEN's.
async function paneAt(page, link, width, height) {
  await page.send("Emulation.setDeviceMetricsOverride", { width, height, deviceScaleFactor: 1, mobile: false }, page.session);
  const loaded = new Promise((done) => link.on("Page.loadEventFired", done));
  await page.send("Page.navigate", { url: atStep(0) }, page.session);
  await loaded;
  return evaluate(page, PANE_SEEN);
}

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
  await page.send("Page.addScriptToEvaluateOnNewDocument", { source: PILL_BEFORE_CANVAS }, page.session);
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
  await page.send("Page.navigate", { url: held(url) }, page.session);
  await loaded;
  const first = moving ? await evaluate(page, FIRST_PAINT) : { skipped: true };
  if (first.skipped) {
    // Only stills were asked for.
  } else if (first.missing) {
    failures.push("the canvas never painted a frame");
  } else {
    const navStart = await evaluate(page, "performance.timeOrigin + 0");
    console.log(`first painted frame ${Math.round(first.painted)} ms after navigation, ${first.colours} colours sampled (origin ${Math.round(navStart)})`);
    await evaluate(page, CANVAS_HASH);
    const warm = await evaluate(page, warmUpWatch(firstFrame));
    const shotStart = Date.now();
    if (warm.unheld !== undefined) {
      failures.push(`the page never held its start ${warm.unheld}, as ?hold=1 asks`);
    } else {
      const edge = (at) => `${at.indicator ? "under" : "without"} the indicator, phase ${at.phase}, ${at.same ? "the first frame" : "not the first frame"}`;
      console.log(
        `warm-up: held before it ${edge(warm.before)} and after it ${edge(warm.after)}; ` +
          `the canvas changed in ${warm.changed} of ${warm.samples} samples between; phase ${warm.phase} after ${Math.round(warm.ms)} ms`,
      );
      const shownWarming = (at) => at.indicator && at.phase === "warming";
      if (!shownWarming(warm.before) || !shownWarming(warm.after)) failures.push("the first frame was not shown warming up under its indicator");
      const changed = warm.changed + (warm.before.same ? 0 : 1) + (warm.after.same ? 0 : 1);
      if (changed > 0) {
        failures.push(`the canvas changed during the warm-up, in ${changed} of ${warm.samples + 2} looks`);
        console.log(`warm-up: first frame ${firstFrame}, before ${warm.before.hash}, after ${warm.after.hash}, seen ${warm.seen.join(" ")}`);
      }
      if (warm.phase !== "riding") failures.push(`the ride never started: phase ${warm.phase} after ${Math.round(warm.ms)} ms`);
      if (warm.ride === null) failures.push("the ride never drew a frame");
      else rideFrame = warm.ride;
    }
    const pillEarly = await evaluate(page, "window.__pillBeforeCanvas === true");
    console.log(`warm-up: indicator ${pillEarly ? "up" : "not up"} before the canvas existed`);
    if (!pillEarly) failures.push("the warming-up indicator was not up while the wasm loaded");
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
      console.log(`shot ${path} at ${Date.now() - shotStart} ms after the ride started`);
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
  // The code pane, wide and narrow, for a page that has one.
  const wide = await paneAt(page, link, 1440, 900);
  if (wide.none) {
    console.log("code pane: none");
  } else if (wide.empty) {
    failures.push("the code pane showed no code at 1440 by 900");
  } else {
    const { data } = await page.send("Page.captureScreenshot", { format: "png" }, page.session);
    writeFileSync(join(shots, "pane_1440x900.png"), Buffer.from(data, "base64"));
    const narrow = await paneAt(page, link, 1000, 700);
    console.log(`code pane: ${wide.first}`);
    if (!wide.shown || !wide.beside) failures.push("the code pane is not beside the canvas, as tall as it, at 1440 by 900");
    if (narrow.shown) failures.push("the code pane shows at 1000 by 700, below its breakpoint");
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
