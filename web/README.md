# web

The page's side of a screensaver: `platform/` and `build.zig`, the wasm
platform and its host; `canvas_app_runner.js`, which loads the wasm, runs the
clock and the keyboard, and dresses the page in the app's skin; and
`shapes_canvas.js`, which paints a frame's shapes on a canvas. The runner and
the painter began as roc-apps' copies and evolve here on their own.

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
