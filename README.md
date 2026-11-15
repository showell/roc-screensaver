# roc-screensaver

Write a screensaver in Roc, and get both a Windows screensaver (`.scr`) and a
web page from the same app.

An app is one Roc value, a `CanvasApp`: a model, a step from one model to
the next, and the shapes each model looks like. Two platforms run it:

- **native:** a Zig host that steps the model, reads each frame out of Roc's
  memory and paints it with a software rasterizer (`host/raster.zig`, from
  angry-gopher). On Windows that is a real screensaver; on Linux it writes
  PNGs.
- **web:** a wasm platform and a small JavaScript runner that paint the same
  shapes on a canvas.

Only the platform changes between the two. Keyboard controls belong to the
app, in Roc, so they work the same on the page and in the Windows window.

## Lanterns

`screensavers/lanterns/` is the one screensaver so far, a sunrise made for
Roc's 0.1.0 launch: the Roc bird hops from lamp to lamp down an endless road
as the sun comes up, and a small plane tows a "Welcome to Roc!" banner across
the sky. Space pauses, R restarts at dawn, and → skips ahead a crossing. Its
own README describes the scene.

- **On the web:** http://143.244.172.148:9210/lanterns/ (the dev channel).
- **On Windows:** open the newest successful run of the
  [Windows screensaver workflow](https://github.com/showell/roc-screensaver/actions/workflows/windows.yml),
  download its `windows-screensaver` artifact (you need to be signed in to
  GitHub), and unzip it. Right-click `screensaver.scr` and choose **Install**
  to make it your screensaver, or double-click `screensaver.exe` for a window
  that takes the keys (Q or Esc quits).

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
- **`page.html`**, which names the wasm.

The app itself uses `lib/`: `Shapes` and `Brush` to draw, `Font` for
lettering the native painter can draw, `Input` and `Keys` for the keyboard,
and `CanvasApp` to put it together. Copy lanterns' `main.roc`, `web.roc` and
`page.html` to start. `zig build -Dapp=<folder>/main.roc` builds another app
in place of lanterns. The page's build, the gate and the Windows workflow
name lanterns alone for now; a second screensaver adds its name to each.

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
    zig build test                # the seam against roc glue, frames painted and freed, keys
    zig build -Dwindows           # zig-out/bin/screensaver.exe and .scr (x86_64-windows, from Linux too)
    shale tools/web_build.shale   # the page, into the dev channel (opt=dev: quick; dest=NAME: another folder)
    shale tools/verify.shale      # the gate: every check above and the live page, a line each
    shale tools/glue.shale        # after a change to platform/: roc glue's snapshot again

On GitHub, `gh workflow run windows.yml` builds the screensaver on a Windows
runner, runs it headless (its last frame's checksum must match the PNG
harness's) and uploads the artifact; `gh run download <run-id> -n
windows-screensaver` fetches it.

## Status (2026-11-15)

- **Works:** lanterns builds and runs both ways. The native PNG frames match
  the page's stills at the same steps, and the Windows build passes on GitHub
  with the harness's checksum.
- **Untested:** nobody has yet run the `.scr` on a real Windows machine. Its
  fullscreen, preview and window modes have only been compiled, and whether
  it holds 30 frames a second fullscreen is unknown.
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
- `screensavers/lanterns/`: the screensaver.
- `examples/`: the host tests' fixtures: `basic/` draws every kind of
  `Frame` shape, and `keys/` counts the keys it is given.
- `tools/`: the gate, the page's build, the glue regenerator, and
  `web_shots.mjs`, which checks a live page in headless Chromium.

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
