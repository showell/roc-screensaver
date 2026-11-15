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
`LanternsApp.roc`) of twenty crossings and a closing perch: 20 legs of 66
steps and 30 more, 1350 steps, 45 seconds. It opens at dawn with the sun
hidden behind the far range's ridge, which is drawn over it, in the notch at
its lowest point; the sun climbs a straight path out of the notch, first
peeks over the ridge at step 199, just after the third crossing, and is clear
of it at step 765, about 0.57 of the way through. The sky, the range, the hills, the grass
and the road brighten at an even pace with it, to the last step, while the
lamps' halos and pools, strongest at dawn, ease off (they stay faintly lit).
The grass is a fresh green throughout, dusky enough at dawn for the pools to
show on it. Then the whole model starts again from its first frame, road,
bird, camera and sun, so every cycle is the same.

Partway through, a small plane tows a banner across the sky that reads
"Welcome to Roc!" (`BannerPlane.roc`). It is a red high-wing light aircraft,
about 60 pixels long, flying high from left to right on a tow line, with the
pale banner rippling behind it. Its nose comes in from the left edge at step
400 (about 13 s), it crosses at 1.75 pixels a step, and its banner's tail
leaves the right edge at step 1174 (about 39 s), so the sky is empty again for
the last few seconds before the rewind. Where it is depends on the cycle's
step alone, so R, the rewind and → move it with everything else. An expect
holds it clear of the sun's disc and at least 20 pixels above the bird's
drawing at every step it is in view. The banner's letters are strokes from
`lib/Font.roc`, copied from roc-apps, since the native painter has no `Text`;
they reach raster.zig as quads like any other shape.

A viewer can steer it with three keys, which the app reads from its step's
`Input.Snapshot`, so they work the same on the page and in the Windows dev
window. Each acts on the step a key is struck, never while it is held:

- **Space** pauses, holding the bird, the camera and the sun still, and a
  second Space resumes from the same moment.
- **R** starts again at dawn, from the first frame, as the cycle's own rewind
  does, and plays: a restart from a pause plays too.
- **→** skips ahead one crossing, a leg of 66 steps played at once, so the
  sun, the light and the bird all move on together; past the cycle's end it
  wraps as the cycle does. Holding it skips once, and a paused scene skips and
  stays paused.

With no key struck it plays on by itself. The real screensaver (`/s`) ends
on any key, so it never sees them.

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
near the top when its skin shows one (below, "Skins"), as soon as the wasm is ready. Firefox compiles a wasm module
twice, a quick tier and then an optimizing one in the background, and frames
drawn before it switches run slowly, so the runner computes, decodes and
paints throwaway frames of the same model onto a canvas a few pixels wide for
up to 0.4 s (stopping sooner once the frames have plainly sped up and
settled), then fades the pill and starts the ride from that frame. Nothing in
the warm-up steps the model. `?timing=1` logs how many throwaway frames ran,
how long they took, and each one's time. In headless Chromium it runs about
110 to 130 frames in 0.3 s, from about 4 ms a frame to about 1 ms; Firefox
itself is not on this box, so the effect there is unmeasured.

### Skins

A skin is the page's dressing around an app, and only the page's: it never
changes the app, and the native build never sees it. It is a Roc value,
`Skin.Skin` in `lib/Skin.roc`, which an app's web root chooses and hands to
the page with `WasmApp.program_with_skin(app, skin)` (`WasmApp.program(app)`
dresses it in `Skin.bare`, which shows nothing). It holds:

- **`show_loading_indicator`**: whether the "warming up" pill shows over the
  first frame. The warm-up runs either way.
- **`show_keyboard_help`**: whether the app's keyboard help shows under the
  canvas. The help itself is the app's: each `CanvasApp` declares its
  `controls`, a list of `{ keys, does }`, and `CanvasApp.help_line` makes
  the one line from them (the lanterns' is "Space pauses and resumes · R
  restarts at dawn · → skips ahead a crossing"). A native runner ignores
  `controls`.
- **`links`**: a list of `{ label, url }`, shown as small text links beside
  the help, each opening in a new tab (`noopener noreferrer`).

The page reads it once, at the start: the web platform's `dressing` entry
answers a boxed `Skin.Dressing`, the skin with the help line, and the
runner reads it through the glue `roc glue` generates (`RocGlue.dressing`),
as it reads a frame. The help and the links go in one quiet line under the
canvas; with a skin that shows neither, the page is the canvas alone.
The lanterns' `web.roc` holds Steve's skin: the indicator and the help on,
and the links Home (https://roc.lynrummy.com) and Code (this repo).

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

The step takes the keyboard: the keys held and the keys struck since the
last step, two bit sets in `lib/Keys.roc`'s bits, as the page's runner
passes them. `NativeApp` makes them an `Input.Snapshot` for the app's
`model_at_next_step`, so an app reads the same keys natively as on the page;
the pointer is `Mouse.none` natively, since no host passes one yet. Only the
Windows dev window passes keys: every key the app has a name for but Q,
which with Esc closes the window and never reaches the app. `/s` keeps the
screensaver's contract (any key ends it), `/p` takes no input, and the
headless run and the PNG harness pass none, so their frames don't move.
The keys example (`examples/keys/`) counts its keys, and `zig build test`
shows a key struck in the host reach its step; nobody has yet pressed one in
the real window.

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
    zig build test              # the seam against roc glue; the basic example's frames painted and freed; the keys example's keys
    shale tools/web_build.shale # the lanterns page, into the dev channel (opt=dev: the dev backend; dest=NAME: another folder)
    zig build -Dwindows         # zig-out/bin/screensaver.exe and screensaver.scr (x86_64-windows)
    zig build -Dwindows headless  # on Windows: the .exe with no window, the last frame's checksum
    shale tools/verify.shale    # the gate: every check, a line each (dest=NAME: a branch's page folder)
    shale tools/glue.shale      # after a change to platform/: roc glue's snapshot again

`-Dapp=<path to main.roc>` builds another app in place of the lanterns.

The Windows build runs on GitHub Actions by hand: `gh workflow run
windows.yml`, then `gh run download <run-id> -n windows-screensaver`.
To install it, right-click `screensaver.scr` and choose Install; run with
no arguments, it is a dev window whose keys go to the app (Q or Esc quits).

## Layout

- `platform/main.roc`: the platform. What it requires of an app
  (`init`, `step`, `frame`, `size`, `fps`, over a boxed model; `step` takes
  the frame number and the keys, `{ held : U32, struck : U32 }`) and the
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
- `host/keyboard.zig`: the keys a window keeps between two steps, and the
  Win32 virtual keys in `lib/Keys.roc`'s bits; `host/keys_test.zig` runs the
  keys example through it.
- `host/png_main.zig`: the headless harness behind `zig build png`.
- `host/win32.zig`: the Windows screensaver: its `.scr` modes (`/s`
  fullscreen, `/p <hwnd>` preview, `/c` config, no arguments a dev
  window, the one mode that passes keys), and `--headless=<N>` for CI. The main thread alone calls Roc,
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
- `lib/`: the canvas apps' vocabulary (`Shapes`, `Brush`, `Font`, `CanvasApp`,
  `WasmApp`), copied from roc-apps, and `Skin`, the page's dressing (above).
- `web/`: the page's wasm platform and host, `shapes_canvas.js` and
  `canvas_app_runner.js`, copied from roc-apps.
- `screensavers/lanterns/`: the screensaver (above). Its bird, flight and
  camera are adapted from Safari's.
- `examples/basic/`: a small app that uses every kind of shape and fill
  directly, the host tests' fixture.
- `examples/keys/`: a canvas app on `NativeApp` whose frame counts the keys
  its step was given, the keys test's fixture.
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
