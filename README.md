# roc-screensaver

A Roc platform for a software-rendered screensaver. An app gives the
platform a model, a step from one model to the next, and the frame each
model looks like: a sky, the camera's roll, a sun and a list of shapes. The
Zig host steps the model at the app's pace, reads each frame out of Roc's
memory, and paints it with a software rasterizer copied from angry-gopher.

## The lanterns screensaver

`screensavers/lanterns/` is the screensaver, a sunrise made for Roc's 0.1.0
launch: the Roc bird, Safari's bird and flight, hopping from lamp to lamp
down an endless road as the sun comes up, crossing it each way in turn, each hop one lamp further on. The camera
moves down the road at one constant speed, the bird's pace over a leg, so the
bird draws ahead through each flight and the camera catches up through each
perch. The lamps, their halos and the pools of light they throw on the road
are its own; the bird is drawn at 4.2 m, nearly twice Safari's 2.2, in every
pose.

The scene runs in a cycle (`Sunrise.roc`, and the counts in
`LanternsApp.roc`) of thirteen crossings and a closing perch: 13 legs of 66
steps and 30 more, 888 steps, about 30 seconds. It opens at dawn with the sun
hidden behind the far range's ridge, which is drawn over it, in the notch at
its lowest point; the sun climbs a straight path out of the notch, first
peeks over the ridge at step 200, just after the third crossing, and is clear
of it about 0.6 of the way through. The sky, the range, the hills, the grass
and the road brighten at an even pace with it, to the last step, while the
lamps' halos and pools, strongest at dawn, ease off (they stay faintly lit).
The grass is a fresh green throughout, dusky enough at dawn for the pools to
show on it. Then the whole model starts again from its first frame, road,
bird, camera and sun, so every cycle is the same.

One app value, `LanternsApp.canvas_app` (a lib `CanvasApp`), runs both ways:

- as a live page, through `web.roc` and lib's `WasmApp`, stepped thirty
  times a second by `web/canvas_app_runner.js` and painted by
  `web/shapes_canvas.js`: `shale tools/web_build.shale` builds it into the
  dev channel, http://143.244.172.148:9210/lanterns/ (`?step=N` shows the
  frame after N steps and stops there, for a side-by-side). The build is
  Roc's `--opt=speed` wasm, about 140 KB and 8 s, which is what is served;
  `shale tools/web_build.shale opt=dev` builds the dev backend's (about
  400 KB) for quick iteration;
- natively, through `main.roc` and `native/NativeApp.roc`, whose
  `native/FrameOfShapes.roc` turns each frame's shapes into a `Frame` that
  host/raster.zig paints: the PNG harness, and the Windows `.scr`.

The page starts on its first frame, still, under a small "warming up" pill
near the top, as soon as the wasm is ready. Firefox compiles a wasm module
twice, a quick tier and then an optimizing one in the background, and frames
drawn before it switches run slowly, so the runner computes, decodes and
paints throwaway frames of the same model onto a canvas a few pixels wide for
up to 0.4 s (stopping sooner once the frames have plainly sped up and
settled), then fades the pill and starts the ride from that frame. Nothing in
the warm-up steps the model. `?timing=1` logs how many throwaway frames ran,
how long they took, and each one's time. In headless Chromium it runs about
110 to 130 frames in 0.3 s, from about 4 ms a frame to about 1 ms; Firefox
itself is not on this box, so the effect there is unmeasured.

`zig build png -- out/x 20 48` and `node tools/web_shots.mjs <page url>
out/y step=20 step=48` write `step-020.png` and `step-048.png` each way, the
same frame, to be laid side by side.

### The adapter

`native/FrameOfShapes.roc` maps each brush to the `Frame` fill that paints
the same colours, and is the one Safari's native build would use:

- **Flat**: opaque, `Solid`; translucent, a `Linear` whose two stops are that
  colour (the same everywhere); unseen, nothing. On a disc, raster.zig's own
  disc with its alpha. The lanterns paint no flat disc (a globe falls back to
  one only when too thin to shade, which no lamp is), so this path is held
  only by the adapter's own expect, and raster.zig's disc only by the basic
  example, which draws `Frame`'s `Disc` directly.
- **Span**: `Round`, when the span covers the region's own width and both
  colours are opaque, as `Brush.width_shade` makes it; any other span, two
  halves cut at its middle, each a `Linear` from the edge colour to the middle.
- **Radial**: `Radial` from the centre; with an inner radius, an `Elliptical`
  whose two axes are the outer radius and whose first stop is part way out.
- **Linear** and **Ellipse**: `Linear` and `Elliptical`, an offset past
  either end made a stop at that end in the colour the gradient has there.
- **A disc with a gradient**: the polygon round it, 12 to 96 sides.

What raster.zig cannot do, approximated or refused:

- **`Round` comes back within a level per channel.** Its colour and strength
  are read back from the span's rounded edge and middle colours (0x804020 at
  0.8 comes back 0x804120).
- **`Glow` loses its middle stop**: raster.zig's gradients have two, so it
  runs straight from its inner colour to its outer. The lanterns use none.
- **`Blend(Add)` is painted as `Over`**: raster.zig only paints over. The
  lanterns use none.
- **`View(World)`, `Image` and `Text` crash**, naming themselves: there is no
  native counterpart yet. The lanterns use none; Safari's native build will
  need `View` and `Text` first.
- **Edges**: raster.zig samples twice each way, a canvas antialiases
  exactly, so an edge differs by a shade.
- **The background** is black with no sun, since a canvas app paints its own
  sky; it shows only where the shapes leave the screen bare.

## Status (2026-11-15)

The lanterns screensaver is new today, with its sunrise cycle and its
constant-speed camera. Its page builds into the dev channel and animates
there, and the native PNG frames and the page's stills at the same steps
(the first, and mid-rise) look the same to the eye. The Windows build compiles it; whether
it holds 30 frames a second as a real screensaver is untested, since its sky
and halos are gradients over most of the screen. The basic example stays as
the host tests' fixture.

The platform: on Linux an app builds, its frames are painted headlessly as
PNGs, the host's view of the frame is held to `roc glue`'s, and every
allocation Roc makes is shown freed. There is no Linux window.

On Windows the lanterns build as a screensaver (`.exe` and `.scr`), on
GitHub Actions and, it seems, from this Linux box too: the x64win archive
links with zig's mingw target and no SDK. CI runs it headless; nobody has
yet watched it as a real screensaver, so the window, preview and
fullscreen modes are untested beyond compiling. The frame type is likely
to move as a real app uses it.

## Before you build

- **Zig 0.17.0.**
- **The pinned Roc**, the nightly named in `roc-version`, installed at
  `~/tools/roc-<pin>/roc` (or named with `-Droc=<path>`). `zig build`
  refuses any other: it runs `roc version` and stops unless it names the
  pin.

## Building and checking

    zig build                   # the lanterns' archive (roc build, dev backend), then the harness
    zig build png -- out/x      # its first 8 frames, out/x/frame-000.png ...
    zig build png -- out/x 48   # the frame after 48 steps, out/x/step-048.png
    zig build test              # the seam against roc glue; the basic example's frames painted and freed
    shale tools/web_build.shale # the lanterns page, into the dev channel (opt=dev: the dev backend)
    zig build -Dwindows         # zig-out/bin/screensaver.exe and screensaver.scr (x86_64-windows)
    zig build -Dwindows headless  # on Windows: the .exe with no window, the last frame's checksum
    shale tools/verify.shale    # the gate: every check, a line each
    shale tools/glue.shale      # after a change to platform/: roc glue's snapshot again

`-Dapp=<path to main.roc>` builds another app in place of the lanterns.

The Windows build runs on GitHub Actions by hand: `gh workflow run
windows.yml`, then `gh run download <run-id> -n windows-screensaver`.
To install it, right-click `screensaver.scr` and choose Install; run with
no arguments, it is a dev window (Space pauses, Q or Esc quits).

## Layout

- `platform/main.roc`: the platform. What it requires of an app
  (`init`, `step`, `frame`, `size`, `fps`, over a boxed model) and the
  entries it provides the host (`roc_init`, `roc_step`, `roc_frame`,
  `roc_release_frame`, `roc_release_model`, `roc_width`, `roc_height`,
  `roc_fps`).
- `platform/Frame.roc`: the frame: a background and a list of shapes, each
  a disc or a polygon with a fill (solid, round, radial, linear or
  elliptical).
- `host/abi.zig`: the seam: the entries, the frame mirrored as extern
  structs in Roc's field order, and the runtime (allocator, crash).
- `host/words.zig`: a frame's shapes written as the rasterizer's
  draw-command words.
- `host/screensaver.zig`: the model held and stepped, each frame painted.
- `host/png_main.zig`: the headless harness behind `zig build png`.
- `host/win32.zig`: the Windows screensaver: its `.scr` modes (`/s`
  fullscreen, `/p <hwnd>` preview, `/c` config, no arguments a dev
  window), and `--headless=<N>` for CI. The main thread alone calls Roc,
  taking each frame's words; two workers rasterize them. Copied from
  angry-gopher's `games/driving/native/`, whose top comment it keeps.
- `.github/workflows/windows.yml`: the Windows build on a hosted runner,
  run by hand.
- `host/raster.zig`, `host/png.zig`: the rasterizer and the PNG encoder,
  copied unchanged from angry-gopher's `games/driving/native/`.
- `host/glue/platform_abi.zig`: `roc glue`'s output for the platform,
  checked in; `host/abi_test.zig` holds `host/abi.zig` to it at compile
  time, field by field and tag by tag.
- `native/`: the package that runs a lib `CanvasApp` on this platform:
  `NativeApp.roc`, and `FrameOfShapes.roc`, the adapter.
- `lib/`: the canvas apps' vocabulary (`Shapes`, `Brush`, `CanvasApp`,
  `WasmApp`), copied from roc-apps.
- `web/`: the page's wasm platform and host, `shapes_canvas.js` and
  `canvas_app_runner.js`, copied from roc-apps.
- `screensavers/lanterns/`: the screensaver (above). Its bird, flight and
  camera are adapted from Safari's.
- `examples/basic/`: a small app that uses every kind of shape and fill
  directly, the host tests' fixture.
- `tools/`: the gate, the glue regenerator, the page's build and
  `web_shots.mjs`, which shoots the page in headless Chromium.

## Pitfalls

- **A record crosses in Roc's order, not the source's**: by alignment,
  then by name, with a tag union's tag byte after its payload and its tags
  numbered alphabetically. Change `platform/Frame.roc`, then run
  `shale tools/glue.shale`; `zig build test` names any field
  `host/abi.zig` now lays out differently.
- **The platform's own functions must name the app's `Model`.** A
  `release_model_for_host : Box(model) -> {}` passes `roc check` but
  crashes at run time with "hit a runtime error"; `Box(Model) -> {}`
  works. The entries that only pass `program`'s functions through carry no
  annotation, because a polymorphic annotation on a non-function is
  refused.
- **`roc glue` needs Roc's Zig glue spec**, which the compiler doesn't
  ship. `tools/glue.shale` reads it from a source checkout at
  `~/tools/roc-<commit>`, and for this pin falls back to
  `~/tools/roc-0602c5f`, whose glue spec was checked byte for byte the same.
- **The rasterizer fills at most 1024 points a polygon**; the host stops
  on a longer one rather than draw part of it.

## License

UPL 1.0; see `LICENSE`.
