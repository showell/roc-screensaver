# The tides screensaver, natively: the app the host paints with raster.zig,
# from the same TidesApp the page runs.
app [Model, program] {
	lib: "../../lib/main.roc",
	native: "../../native/main.roc",
	pf: platform "../../platform/main.roc",
}

import native.NativeApp
import TidesApp

Model : TidesApp.Model

program = NativeApp.program(TidesApp.canvas_app)
