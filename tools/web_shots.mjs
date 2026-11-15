// web_shots.mjs loads a built screensaver page in headless Chromium and saves
// screenshots of it at a few times after its first painted frame, so a run can
// be seen playing. It exits non-zero on a console error, an exception, a
// failed request or a canvas that never paints.
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
  });
  link.on("Network.responseReceived", ({ response }) => { if (response.status >= 400) failures.push(`${response.status} for ${response.url}`); });
  link.on("Network.loadingFailed", ({ canceled, errorText }) => { if (!canceled) failures.push(`a request failed: ${errorText}`); });
  for (const domain of ["Page", "Runtime", "Network"]) await page.send(`${domain}.enable`, {}, page.session);
  // 700 high, so a 600-high canvas within the runner's 88vh is drawn at its own size.
  await page.send("Emulation.setDeviceMetricsOverride", { width: 1000, height: 700, deviceScaleFactor: 1, mobile: false }, page.session);
  const steps = times.filter((t) => t.startsWith("step="));
  for (const step of steps.map((t) => Number(t.slice(5)))) {
    const shown = new Promise((done) => link.on("Page.loadEventFired", done));
    await page.send("Page.navigate", { url: `${url}?step=${step}` }, page.session);
    await shown;
    const still = await evaluate(page, FIRST_PAINT);
    if (still.missing) { failures.push(`step ${step}: the canvas never painted`); continue; }
    const box = await evaluate(page, "(() => { const r = document.querySelector('canvas').getBoundingClientRect(); return { x: r.left, y: r.top, width: r.width, height: r.height }; })()");
    const { data } = await page.send("Page.captureScreenshot", { format: "png", clip: { ...box, scale: 1 } }, page.session);
    const path = join(shots, `step-${String(step).padStart(3, "0")}.png`);
    writeFileSync(path, Buffer.from(data, "base64"));
    console.log(`shot ${path}, the canvas ${box.width} by ${box.height}`);
  }
  const loaded = new Promise((done) => link.on("Page.loadEventFired", done));
  await page.send("Page.navigate", { url }, page.session);
  await loaded;
  const first = steps.length === times.length ? { skipped: true } : await evaluate(page, FIRST_PAINT);
  if (first.skipped) {
    // Only stills were asked for.
  } else if (first.missing) {
    failures.push("the canvas never painted a frame");
  } else {
    const navStart = await evaluate(page, "performance.timeOrigin + 0");
    console.log(`first painted frame ${Math.round(first.painted)} ms after navigation, ${first.colours} colours sampled (origin ${Math.round(navStart)})`);
    const shotStart = Date.now();
    for (const at of times.filter((t) => !t.startsWith("step=")).map(Number)) {
      const wait = at - (Date.now() - shotStart);
      if (wait > 0) await sleep(wait);
      const { data } = await page.send("Page.captureScreenshot", { format: "png" }, page.session);
      const path = join(shots, `at_${String(at).padStart(5, "0")}ms.png`);
      writeFileSync(path, Buffer.from(data, "base64"));
      console.log(`shot ${path} at ${Date.now() - shotStart} ms after first paint`);
    }
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
