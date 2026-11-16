# roc-screensaver

A Roc platform, written in Zig, that turns one Roc app into both a Windows
screensaver (`.scr`) and a web page.

Even if you don't intend to build a screensaver, this repo may be instructive
for Roc newcomers. It shows how to write a Roc app that runs on more than one
platform, and its `lib/` has helpers (shapes, brushes, colors, lettering,
keyboard input) for building things like game engines.

## What it gives you

- **A native platform in Zig, the heart of the repo.** The host steps your
  app's model, reads each frame out of Roc's memory, and paints it with its
  own software rasterizer (`host/raster.zig`). It needs no GPU and no
  graphics library. On Windows that is a real screensaver, fast enough for
  30 frames a second on one thread (see Status). On Linux it writes PNGs.
- **A web preview of the same app.** A wasm platform and a small JavaScript
  runner paint the same shapes on a canvas, so you see each change in a
  browser in seconds, long before a Windows machine is involved. The gate
  holds the two to the same picture: the page's first frame must match the
  native harness's at the same step.

An app is one Roc value, a `CanvasApp`: a model, a step from one model to the
next, and the shapes each model looks like. Only the platform changes between
the two. Keyboard controls belong to the app, in Roc, so they work the same on
the page and in the Windows window.

## The screensavers

Each one has its own folder in `screensavers/` and its own README.

- **Lanterns** (`screensavers/lanterns/`): a sunrise made for Roc's 0.1.0
  launch. The Roc bird hops from lamp to lamp down an endless road as the sun
  comes up, a small plane tows a "Welcome to Roc!" banner across the sky,
  and five jets fly over before the cycle starts again. Space pauses, R
  restarts at dawn, and → skips ahead a crossing.
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
  few links, each opening in a new tab. `WasmApp.program(app)` shows none of
  them.
- **`page.html`**, which names the wasm, `<folder>.wasm`.
- **a line in `screensavers/list.txt`**, the one place that names the
  screensavers: its folder, the checksum of its eighth native frame, its
  expect counts, the step of its landing-page picture (`shot.png`, or `-`
  for none) and its keyboard help. The page's build, the gate and the
  Windows workflow each take every screensaver listed there, so a new one
  is one more line (the file's header says what each field is).

The app itself uses `lib/`: `Shapes` and `Brush` to draw, `Font` for
lettering the native painter can draw, `Input` and `Keys` for the keyboard,
and `CanvasApp` to put it together. Copy tides' `main.roc`, `web.roc` and
`page.html` to start. `zig build -Dapp=<folder>/main.roc` builds another app
in place of lanterns.

Not every shape reaches Windows yet: the native painter has no `Text`, `Image`
or `View(World)`, and paints `Blend(Add)` as ordinary blending.
`native/README.md` says what each shape becomes natively.

## Building and checking

You need **Zig 0.17.0** and **the pinned Roc**, the nightly named in
`roc-version`, at `~/tools/roc-<pin>/roc` (or name it with `-Droc=<path>`).
`zig build` refuses any other Roc.

    zig build                     # lanterns' archive, then the PNG harness
    zig build png -- out/x        # its first 8 frames, out/x/frame-000.png ...
    zig build png -- out/x 48     # the frame after 48 steps, out/x/step-048.png
    zig build bench -Doptimize=ReleaseFast   # one cycle's frame times by phase, then win32's two-worker pipeline (about a minute)
    zig build test                # the seam against roc glue, frames painted and freed, keys, raster's fast paths
    zig build -Dwindows           # zig-out/bin/lanterns.exe and .scr (x86_64-windows, ReleaseFast, from Linux too)
    shale tools/web_build.shale   # every listed screensaver's page and shot.png, into the dev channel (saver=NAME: one; opt=dev: quick; dest=NAME: another folder)
    shale tools/verify.shale      # the gate: every check above for every listed screensaver, and the live pages, a line each
    shale tools/glue.shale        # after a change to platform/: roc glue's snapshot again

On GitHub, `gh workflow run windows.yml` builds each screensaver on a Windows
runner, runs it headless (its last frame's checksum must match the PNG
harness's) and uploads the artifact; `gh run download <run-id> -n
windows-screensaver` fetches it.

## Status (2026-11-15)

- **Works:** lanterns builds and runs both ways. The native PNG frames match
  the page's stills at the same steps, and the Windows build passes on GitHub
  with the harness's checksum.
- **Untested:** nobody has yet run the `.scr` on a real Windows machine. Its
  fullscreen, preview and window modes have only been compiled.
- **Fast enough for 30 frames a second, on one thread:** `win32.zig`
  rasterizes every frame at the app's size times `raster.SS`, 1920 by 1200,
  in every mode, and GDI's HALFTONE stretch fits that to the window, or in
  `/s` to the monitor's shape, whatever its aspect (a 16:9 monitor squeezes
  the 16:10 frame). Two workers each rasterize whole frames, alternately.
  `zig build bench` measures it on Linux (this box: two DigitalOcean vCPUs,
  ReleaseFast), stepping the whole 1350-step cycle and drawing every sixth
  step, against 33.3 ms a frame:

  | phase (one thread) | median | p95 | worst |
  |---|---|---|---|
  | Roc frame (`roc_frame` and its release) | 1.61 ms | 2.21 ms | 2.87 ms |
  | Roc step | 0.00 ms | 0.01 ms | 0.03 ms |
  | words, written and copied into a slot | 0.02 ms | 0.02 ms | 0.07 ms |
  | raster: the sky and grass, then the sun | 1.52 ms | 1.72 ms | 6.35 ms |
  | raster: the shapes | 12.8 ms | 17.2 ms | 20.2 ms |
  | the whole frame | 16.0 ms | 21.0 ms | 24.0 ms |

  No drawn frame is over the budget. That is for this box's own CPU; built
  for the plain x86-64 the Windows screensaver targets (`-Dcpu=baseline`,
  no AVX), the whole frame takes 18.3 ms median, 26.3 ms p95 and 31.1 ms at
  worst, still inside the budget. Of the shapes, `Radial` fills take 69%
  (28 a frame: the halos, the lamps' and the sun's 300-pixel glow), `Linear`
  18% (56: the sky, the grass, the cut spans and the translucent flat
  brushes), `Round` 5% and `Elliptical` 3%. Raster.zig plans each upright
  polygon's fill (fillPoly's `Plan`): a colour that depends on the row
  alone (the sky, the grass, a flat brush) is worked out once a run, one
  that depends on the column alone (a span's halves, a round fill) once a
  column, and the radial, elliptical and slanted gradients eight pixels at
  a time in vectors, each with the per-pixel rule's own operations, so the
  pixels are the same as before (host/raster_test.zig holds them to it).
  Win32's two-worker pipeline reproduced here gives about 110 frames a
  second unpaced (84 at the baseline CPU). GDI's stretch to the monitor is
  not measured. The Windows build is ReleaseFast (`zig build -Dwindows`'s
  default); Debug rasterized about 3.5 times slower.
- **No Linux window:** Linux gets the PNG harness only.

## Layout

- `platform/`: the native platform. `main.roc` says what it requires of an
  app and what it provides the host; `Frame.roc` is the frame the host
  paints.
- `host/`: the Zig host. `abi.zig` is the seam with Roc, held to `roc glue`'s
  output (`glue/platform_abi.zig`) by `abi_test.zig`; `screensaver.zig`
  steps and paints; `win32.zig` is the Windows screensaver (`/s`, `/p`, `/c`,
  a window with no arguments, `--headless=N` for CI); `png_main.zig` is the
  PNG harness. `raster.zig`, `png.zig` and `win32.zig` come from
  angry-gopher's `games/driving/native/`.
- `native/`: runs a `CanvasApp` on the native platform, with the adapter
  from shapes to frames (`native/README.md`).
- `web/`: the wasm platform and its host, and the page's runner and painter
  (`web/README.md`).
- `lib/`: the vocabulary apps are written in, copied from roc-apps and
  allowed to drift, plus `Skin`.
- `screensavers/`: the screensavers, a folder each (`lanterns/`,
  `bubbles/`), and `list.txt`, which names them.
- `examples/`: the host tests' fixtures: `basic/` draws every kind of
  `Frame` shape, and `keys/` counts the keys it is given.
- `tools/`: the gate, the page's build, the glue regenerator, and
  `web_shots.mjs`, which checks a live page in headless Chromium. The
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
