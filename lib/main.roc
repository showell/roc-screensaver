# The vocabulary every screensaver shares, as a package.
#
# A screensaver's page root, web.roc, sits in its own directory and reaches
# this as `lib: "../../lib/main.roc"`; every module of it then says
# `import lib.Shapes`. It declares no platform, so any platform can use it.
#
# This file is copied from roc-apps (`canvas_apps/lib/main.roc`) on 2026-11-15, and it
# is allowed to drift from it. It names only the modules a screensaver here uses.
package
	[
		ArgbColor,
		Brush,
		CanvasApp,
		ColorShade,
		Fraction,
		Input,
		Keys,
		Math,
		Mouse,
		Pixels,
		Point,
		RgbColor,
		Shapes,
		WasmApp,
	]
	{}
