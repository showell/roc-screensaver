# web

The page's side of a screensaver: `platform/` and `build.zig`, the wasm
platform and its host; `canvas_app_runner.js`, which loads the wasm, runs the
clock and the keyboard, and dresses the page in the app's skin; and
`shapes_canvas.js`, which paints a frame's shapes on a canvas. The runner and
the painter began as roc-apps' copies and evolve here on their own.

`lanterns_platform/` is Lanterns' own platform, for its code pane: the
canvas apps' platform with one function more, `code`, which answers after each
step `ModuleSource({ file, html, top_line, pane_lines })`, a new module with
its code coloured as HTML, or `ScrollTo(top_line)`, the line now at the pane's
top. Its host is the shared host (as the `canvas_host` module)
with one export more, `computeCode`, and `code_pane.js` lays the pane beside
the canvas and scrolls it. A web root names its platform, and the page's build
glues against that one and serves its scripts. The runner knows nothing of the
pane but an optional `pane` on `window.SHOW`, which it tells of each step and
shows the canvas; Tides and Bubbles set none.

## The code pane

Lanterns' page is two panes side by side on a window at least 1100 CSS pixels
wide: the scene on the left, at its own aspect ratio (at most 88% of the
window's height, and as wide as the pane leaves room for), and the code on the
right, `clamp(360px, 32vw, 600px)` wide and as tall as the scene. Below
1100 pixels the pane is hidden and the canvas lays out as it always did.

A strip at the pane's top names the module's file, lit for a moment as each
one arrives. The Roc decides which module and when
(`screensavers/lanterns/CodeCues.roc`, a cue a line), and the scroll too, in
lines (`CodePane.roc`): a module holds at its top for up to 20 steps, then
scrolls at an even pace to show its last line at the pane's foot on the step
before the next comes in. The page sizes its lines so that `pane_lines` (32)
fill the code's area, and turns lines into pixels by that height. A pause
holds the scroll, since the Roc's model holds.

## The start

The "warming up" pill goes up the moment the page opens and stays while the
wasm downloads and compiles. The page then shows its first frame, still,
under the pill. Firefox compiles a wasm module twice, a quick tier and then an
optimizing one in the background, and frames drawn before it switches run
slowly. So the runner computes, decodes and paints throwaway frames of the
same model onto a tiny canvas, for a short budget, stopping early once the
frames have plainly sped up and settled (`WARM_BUDGET_MS` and `WARM_LEAST_MS`
in the runner). Then it fades the pill and starts the ride from that same
frame. The warm-up leaves the model where it was. A skin with the pill off
takes it down as soon as the wasm is read; the warm-up runs either way.

`?timing=1` logs how long the load and the warm-up took, and each throwaway
frame's time.
