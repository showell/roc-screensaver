# The native end, as a package: a screensaver's main.roc reaches it as
# `native.NativeApp`, which runs a canvas app on this repo's platform.
#
# It declares the platform itself, because FrameOfShapes builds the platform's
# Frame, and a package may only see a platform it names in its header. Every
# app that uses it names the same one, as roc-apps' `canvas_apps/native/` does
# for roc-ray.
package
	[FrameOfShapes, NativeApp]
	{
		lib: "../lib/main.roc",
		pf: platform "../platform/main.roc",
	}
