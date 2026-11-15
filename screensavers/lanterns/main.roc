# The lanterns screensaver, natively: the app the host paints with raster.zig,
# from the same LanternsApp the page runs.
app [Model, program] {
	lib: "../../lib/main.roc",
	native: "../../native/main.roc",
	pf: platform "../../platform/main.roc",
}

import native.NativeApp
import LanternsApp

Model : LanternsApp.Model

program = NativeApp.program(LanternsApp.canvas_app)
