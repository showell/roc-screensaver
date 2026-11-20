# roc-screensaver

A Roc platform, written in Zig, that turns one Roc app into both a Windows
screensaver (`.scr`) and a web page.

The code here was written by AI coding agents (Claude), with human supervision. Point an agent at this repo and it can build a new screensaver on the platform.

Beyond screensavers, it shows how to write a Roc app that runs on more than one
platform, and its `lib/` has helpers (shapes, brushes, colors, lettering,
keyboard input) for building things like game engines.

## What it gives you

- **A native platform in Zig, the heart of the repo.** The host steps your
  app's model, reads each frame out of Roc's memory, and paints it with its
  own software rasterizer (`host/raster.zig`). It paints on the CPU
  alone. On Windows that is a real screensaver, fast enough for
  30 frames a second on one thread (see Status). On Linux it writes PNGs.
- **A web preview of the same app.** A wasm platform and a small JavaScript
  runner paint the same shapes on a canvas, so you see each change in a
  browser in seconds, before any Windows build. The gate
  holds the two to the same picture: the page's first frame must match the
  native harness's at the same step.

An app is one Roc value, a `CanvasApp`: a model, a step from one model to the
next, and the shapes each model looks like. The two builds differ in the platform
alone. Keyboard controls belong to the app, in Roc, so they work the same on
the page and in the Windows window.

## The screensavers

Each one has its own folder in `screensavers/` and its own README.

- **Lanterns** (`screensavers/lanterns/`): a sunrise made for Roc's 0.1.0
  launch. The Roc bird hops from lamp to lamp down an endless road as the sun
  comes up, a small plane tows a "Welcome to Roc!" banner across the sky,
  and five jets fly over before the cycle starts again. Space pauses, R
  restarts at dawn, and → skips ahead a crossing. On a wide screen the page
  shows, beside the scene, the Roc module behind each moment, coloured.
  On the web: https://roc.lynrummy.com/welcome-to-roc/
- **Tides** (`screensavers/tides/`): six bands of water roll under a sky
  that goes from dawn to day, dusk and night every two minutes. Space
  pauses and R restarts at dawn.
  On the web: https://roc.lynrummy.com/tides/
- **Bubbles** (`screensavers/bubbles/`): translucent purple bubbles rise,
  wobble, and fade or pop near the top. Space pauses and R restarts.
  On the web: https://roc.lynrummy.com/bubbles/

Tides and Bubbles are each one or two small modules, and a good place to start
reading.

**On Windows:** open the newest successful run of the
[Windows screensaver workflow](https://github.com/showell/roc-screensaver/actions/workflows/windows.yml),
and download its `windows-screensaver` artifact, a zip (you need to be
signed in to GitHub). It holds an `.exe` and a `.scr` for each screensaver.
Then:
1. Right-click the zip, choose **Extract All…**, then **Extract**.
   Explorer shows a zip's contents as a preview, and nothing inside can be
   run or installed from there.
2. Double-click `lanterns.exe` for a window that takes the keys (Q or
   Esc quits). It is unsigned, so if Windows says "Windows protected your
   PC", choose **More info**, then **Run anyway**.
3. Right-click `lanterns.scr`, choose **Show more options** (Windows
   11's short menu hides it; Shift+right-click opens the full menu), then
   **Install**, to make it your screensaver.

## Making a screensaver

A screensaver is a folder in `screensavers/` with two roots over one app:

- **`main.roc`**, the native root: `NativeApp` running the app on
  `platform/`.
- **`web.roc`**, the web root: `WasmApp.program_with_skin(app, skin)` on
  `web/platform/`. The skin (`lib/Skin.roc`) dresses the page and only the
  page: whether the "warming up" pill shows, whether the app's keyboard help
  shows under the canvas (made from the `controls` the app declares), and a
  few links, each opening in a new tab. `WasmApp.program(app)` is the bare
  page.
- **`page.html`**, which names the wasm, `<folder>.wasm`.
- **a line in `screensavers/list.txt`**, the one place that names the
  screensavers: its folder, the checksum of its eighth native frame, its
  expect counts, the step of its landing-page picture (`shot.png`, or `-`
  for none) and its keyboard help. The page's build, the gate and the
  Windows workflow each take every screensaver listed there, so a new one
  is one more line (the file's header says what each field is).

The app itself uses `lib/`: `Shapes` and `Brush` to draw (and `WidthShading`
for a fill shaded round across its width), `Font` for
lettering the native painter can draw, `Input` and `Keys` for the keyboard,
and `CanvasApp` to put it together. Copy tides' `main.roc`, `web.roc` and
`page.html` to start. `zig build -Dapp=<folder>/main.roc` builds another app
in place of lanterns.

The native painter draws every shape except `Text`, `Image` and
`View(World)`, and paints `Blend(Add)` as ordinary blending.
`native/README.md` says what each shape becomes natively.

## Building and checking

You need **Zig 0.17.0** and **the pinned Roc**, the nightly named in
`roc-version`, at `~/tools/roc-<pin>/roc` (or name it with `-Droc=<path>`).
`zig build` refuses any other Roc. Lanterns' page also needs
[roc-syntax-color](https://github.com/showell/roc-syntax-color) checked out
beside this repo, at the same pin; the native builds don't.

    zig build                     # lanterns' archive, then the PNG harness
    zig build png -- out/x        # its first 8 frames, out/x/frame-000.png ...
    zig build png -- out/x 48     # the frame after 48 steps, out/x/step-048.png
    zig build bench -Doptimize=ReleaseFast   # one cycle's frame times by phase, then win32's two-worker pipeline (about a minute)
    zig build test                # the seam against roc glue, frames painted and freed, keys, raster's fast paths
    zig build -Dwindows           # zig-out/bin/lanterns.exe and .scr (x86_64-windows, ReleaseFast, from Linux too)
    shale tools/web_build.shale   # every listed screensaver's page and shot.png, into the dev channel (saver=NAME: one; opt=dev: quick; dest=NAME: another folder)
    shale tools/verify.shale      # the gate: every check above for every listed screensaver, and the live pages, a line each
    shale tools/glue.shale        # after a change to platform/: roc glue's snapshot again
    shale tools/bundle_lanterns_sources.shale   # after a change to a Lanterns module: the code pane's sources again

On GitHub, `gh workflow run windows.yml` builds each screensaver on a Windows
runner, runs it headless (its last frame's checksum must match the PNG
harness's) and uploads the artifact; `gh run download <run-id> -n
windows-screensaver` fetches it.

## Status

- **Works:** every listed screensaver builds and runs both ways. The native
  PNG frames match the page's stills at the same steps, and the Windows
  build passes on GitHub with the harness's checksum.
- **Next to try:** the `.scr` on a real Windows machine. Its fullscreen,
  preview and window modes are compiled and wait for that run.
- **Fast enough for 30 frames a second:** `win32.zig` rasterizes each frame
  at 1920 by 1200 and GDI's HALFTONE stretch fits it to the window or the
  monitor. Two workers rasterize whole frames, alternately. `zig build
  bench` measures each phase of a frame against the 33.3 ms budget.

## Layout

- `platform/`: the native platform. `main.roc` says what it requires of an
  app and what it provides the host; `Frame.roc` is the frame the host
  paints.
- `host/`: the Zig host. `abi.zig` is the seam with Roc, held to `roc glue`'s
  output (`glue/platform_abi.zig`) by `abi_test.zig`; `screensaver.zig`
  steps and paints; `win32.zig` is the Windows screensaver (`/s`, `/p`, `/c`,
  a window with no arguments, `--headless=N` for CI); `png_main.zig` is the
  PNG harness.
- `native/`: runs a `CanvasApp` on the native platform, with the adapter
  from shapes to frames (`native/README.md`).
- `web/`: the wasm platform and its host, Lanterns' platform beside it
  (`web/lanterns_platform/`, the code pane's), and the page's runner and
  painter (`web/README.md`).
- `lib/`: the vocabulary apps are written in, copied from roc-apps and
  allowed to drift, plus `Skin`.
- `screensavers/`: the screensavers, a folder each, and `list.txt`, which
  names them.
- `examples/`: the host tests' fixtures: `basic/` draws every kind of
  `Frame` shape, and `keys/` counts the keys it is given.
- `tools/`: the gate, the page's build, the glue regenerator, the code
  pane's bundler and its staleness check, and `web_shots.mjs`, which checks
  a live page in headless Chromium. The
  scripts read `screensavers/list.txt` through `.shale/prelude.shale`'s
  `screensavers_listed`.

## Pitfalls

- **A record crosses in Roc's order, not the source's**: by alignment, then
  by name, with a tag union's tag byte after its payload and its tags
  numbered alphabetically. After a change to `platform/Frame.roc`, run
  `shale tools/glue.shale`; `zig build test` names any field `host/abi.zig`
  now lays out differently.
- **The platform's own functions must name the app's `Model`.** A
  `release_model_for_host : Box(model) -> {}` passes `roc check` but crashes
  at run time with "hit a runtime error"; `Box(Model) -> {}` works.
- **`roc glue` needs Roc's Zig glue spec**, which the compiler doesn't ship.
  `tools/glue.shale` reads it from a source checkout at `~/tools/roc-<commit>`.
- **The rasterizer fills at most 1024 points a polygon**; the host stops on
  a longer one rather than draw part of it.

## License

UPL 1.0; see `LICENSE`.
