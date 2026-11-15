# The bubbles screensaver, natively: the app the host paints with raster.zig,
# from the same BubblesApp the page runs.
app [Model, program] {
	lib: "../../lib/main.roc",
	native: "../../native/main.roc",
	pf: platform "../../platform/main.roc",
}

import native.NativeApp
import BubblesApp

Model : BubblesApp.Model

program = NativeApp.program(BubblesApp.canvas_app)
