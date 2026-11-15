# roc-screensaver

A Roc platform for a software-rendered screensaver. An app gives the
platform a model, a step from one model to the next, and the frame each
model looks like: a sky, the camera's roll, a sun and a list of shapes. The
Zig host steps the model at the app's pace, reads each frame out of Roc's
memory, and paints it with a software rasterizer copied from angry-gopher.

## Status (2026-11-15)

A first spike, Linux only. The example app builds, its frames are painted
headlessly as PNGs, the host's view of the frame is held to `roc glue`'s,
and every allocation Roc makes is shown freed. There is no window yet and
no Windows build; the frame type is likely to move as a real app uses it.

## Before you build

- **Zig 0.17.0.**
- **The pinned Roc**, the nightly named in `roc-version`, installed at
  `~/tools/roc-<pin>/roc` (or named with `-Droc=<path>`). `zig build`
  refuses any other: it runs `roc version` and stops unless it names the
  pin.

## Building and checking

    zig build                   # the example's archive (roc build, dev backend), then the harness
    zig build png -- out/basic  # the example's first 8 frames, out/basic/frame-000.png ...
    zig build test              # the seam against roc glue; the example's frames painted and freed
    shale tools/verify.shale    # the gate: every check, a line each
    shale tools/glue.shale      # after a change to platform/: roc glue's snapshot again

`-Dapp=<path to main.roc>` builds another app in place of the example.

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
- `host/raster.zig`, `host/png.zig`: the rasterizer and the PNG encoder,
  copied unchanged from angry-gopher's `games/driving/native/`.
- `host/glue/platform_abi.zig`: `roc glue`'s output for the platform,
  checked in; `host/abi_test.zig` holds `host/abi.zig` to it at compile
  time, field by field and tag by tag.
- `examples/basic/`: a small app that uses every kind of shape and fill.
- `tools/`: the gate and the glue regenerator.

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
