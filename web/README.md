# web

The page's side of a screensaver: `platform/` and `build.zig`, the wasm
platform and its host; `canvas_app_runner.js`, which loads the wasm, runs the
clock and the keyboard, and dresses the page in the app's skin; and
`shapes_canvas.js`, which paints a frame's shapes on a canvas. The runner and
the painter are copied from roc-apps and allowed to drift.

## The start

The "warming up" pill goes up the moment the page opens and stays while the
wasm downloads and compiles. The page then shows its first frame, still,
under the pill. Firefox compiles a wasm module twice, a quick tier and then
an optimizing one in the background, and frames drawn before it switches run
slowly. So the runner computes, decodes and paints throwaway frames of the
same model, onto a canvas a few pixels wide, for up to 0.4 s, stopping sooner
(but not before 0.15 s) once the frames have plainly sped up and settled. Then it fades the pill and
starts the ride from that same frame. Nothing in the warm-up steps the model.
A skin without the pill takes it down as soon as the wasm is read; the
warm-up runs either way.

`?timing=1` logs how long the load and the warm-up took, and each throwaway
frame's time. In headless Chromium the warm-up runs about 110 to 130 frames
in 0.3 s, going from about 4 ms a frame to about 1 ms.
