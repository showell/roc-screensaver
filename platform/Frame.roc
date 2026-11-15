## A frame is what the screensaver paints at one instant: the background
## (a sky over grass, the camera's roll and the sun), then each shape in
## order, a later shape over an earlier one. Coordinates are the app's
## pixels, x to the right and y down, before the roll turns them about the
## frame's center.
##
## Frame is nominal rather than opaque because every value of it is one the
## host can paint, so an app builds it from a plain record.
Frame := {
	background : Frame.Background,
	shapes : List(Frame.Shape),
}.{

	## An opaque colour, `0xRRGGBB`.
	Rgb : U32

	## A colour with its alpha, `0xAARRGGBB`; an alpha of `0xFF` is opaque.
	Argb : U32

	Point : { x : F32, y : F32 }

	## The sky runs from `sky_top` at the top to `sky_horizon` at the frame's
	## middle, and grass fills the lower half. `roll` turns the whole frame
	## about its center, in radians.
	Background : {
		sky_top : Frame.Rgb,
		sky_horizon : Frame.Rgb,
		roll : F32,
		sun : Frame.Sun,
	}

	## The sun glows behind every shape, in the sky only. A `scale` of 1 is
	## a disc 46 pixels across its radius.
	Sun : [Hidden, Shown({ x : F32, y : F32, scale : F32 })]

	## One thing painted over the frame.
	Shape : [
		## A circle of one colour, `alpha` from 0 (unseen) to 1 (opaque).
		Disc({ center : Frame.Point, radius : F32, color : Frame.Rgb, alpha : F32 }),

		## A polygon's corners in order around its edge, and how it is filled.
		Polygon({ points : List(Frame.Point), fill : Frame.Fill }),
	]

	## How a polygon is filled.
	Fill : [
		## One opaque colour.
		Solid(Frame.Rgb),

		## A horizontal cylinder's shading across the polygon's width: darker
		## at the edges and lighter in the middle, by `strength` from 0
		## (flat) to 1.
		Round({ color : Frame.Rgb, strength : F32 }),

		## `inner` at `center`, fading to `outer` at `radius` and beyond.
		Radial({ center : Frame.Point, radius : F32, inner : Frame.Argb, outer : Frame.Argb }),

		## From `from` to `to`, the colour runs from `start`'s to `end`'s,
		## each stop's `at` a fraction of that line.
		Linear({ from : Frame.Point, to : Frame.Point, start : Frame.Stop, end : Frame.Stop }),

		## An ellipse's gradient about `center`, whose axes are the vectors
		## `u` and `v`; the stops' `at` is a fraction of the way out.
		Elliptical({ center : Frame.Point, u : Frame.Point, v : Frame.Point, start : Frame.Stop, end : Frame.Stop }),
	]

	## A gradient's colour at a fraction of the way along it.
	Stop : { color : Frame.Argb, at : F32 }
}
