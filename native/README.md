# native

`NativeApp.roc` runs a lib `CanvasApp` on the native platform. It turns each
step's keys, two bit sets in `lib/Keys.roc`'s bits, into an `Input.Snapshot`
for the app, so an app reads the same keys natively as on the page. The
pointer is `Mouse.none` natively. The Windows window passes every key the app
has a name for; Q and Esc close the window and stay with the host.

## The adapter

`FrameOfShapes.roc` turns each frame's shapes into a `Frame` that
`host/raster.zig` paints, mapping each brush to the fill that paints the same
colours:

- **Flat**: opaque, `Solid`; translucent, a `Linear` whose two stops are that
  colour; fully transparent, skipped. On a disc, raster.zig's own disc with
  its alpha.
- **Span**: `Round`, when the span covers the region's own width and both
  colours are opaque, as `WidthShading.width_shade` makes it. Any other span
  is cut into two halves at its middle, each a `Linear` from the edge colour
  to the middle.
- **Radial**: `Radial` from the centre. With an inner radius, it becomes an
  `Elliptical` whose two axes are the outer radius and whose first stop is
  part way out.
- **Linear** and **Ellipse**: `Linear` and `Elliptical`. An offset past
  either end becomes a stop at that end, in the colour the gradient has there.
- **A disc with a gradient**: the polygon around it.

## Where native painting differs from the page

- **`Round` comes back within one level per channel**, since its colour and
  strength are read back from the span's rounded colours (0x804020 at 0.8
  comes back 0x804120).
- **`Glow` keeps two of its stops**, as raster.zig's gradients have two.
- **`Blend(Add)` is painted as `Over`**, raster.zig's one blend.
- **`View(World)`, `Image` and `Text` crash**, naming themselves. Letter with
  `lib/Font.roc`'s strokes.
- **Edges differ by a shade**: raster.zig samples twice each way, and a canvas
  antialiases exactly.
- **The background** is black, showing wherever the shapes leave the screen
  bare; a canvas app paints its own sky.
