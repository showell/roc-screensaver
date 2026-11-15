## BannerPlane is the small plane that tows a banner across the sky, reading
## "Welcome to Roc!" for Roc's 0.1.0 launch. It flies in from the left edge
## once the sky has brightened, crosses slowly and high, above every flight of
## the bird, and passes over the sun while the sun is still low; it is gone past
## the right edge before the cycle starts again. Where it is depends on the
## cycle's step alone, so a restart, the rewind and a skip move it with
## everything else.
##
## The plane is a red high-wing light aircraft seen from the side, nose to the
## right. The banner is a pale strip on a tow line behind it, its letters drawn
## as strokes by lib's Font, since the native painter has no typefaces. A slow
## ripple runs down the banner from its leading edge, growing toward its tail.
import RoadCamera
import lib.Brush
import lib.Font
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes

BannerPlane :: [].{

	## Where the plane is `steps` into the cycle: still to come, in the sky with
	## its nose at a point, or gone past the right edge.
	Flight : [Coming, InView(Point), Gone]

	## The plane's flight `steps` into the cycle. At `enters_step` its nose is
	## one step's flying past the left edge; it is gone once its banner's tail is
	## past the right edge. It bobs a little as it goes.
	flight_at : U64 -> BannerPlane.Flight
	flight_at = |steps|
		if steps < enters_step {
			Coming
		} else {
			nose_x = (steps - enters_step + 1).to_f64() * speed
			if nose_x - tail_reach >= RoadCamera.screen_width {
				Gone
			} else {
				bob = bob_height * (F64.tau * steps.to_f64() / bob_steps).sin()
				InView(Point.at(nose_x, cruise_y + bob))
			}
		}

	## What the plane draws `steps` into the cycle: the banner, the tow line and
	## the plane, in the order they are painted, or nothing when it is not in
	## view.
	shapes_at : U64 -> List(Shapes.Shape)
	shapes_at = |steps|
		match flight_at(steps) {
			InView(nose) => banner_shapes({ nose, steps }).concat(tow_line_shapes(nose)).concat(plane_shapes(nose))
			Coming => []
			Gone => []
		}
}

## The step the plane flies in at, about 13 s into the cycle's 45, chosen so the
## sky is bright and the sun has just cleared the ridge's lowest points.
enters_step : U64
enters_step = 400

## How far the plane flies each step, in pixels: about 52 a second, slow enough
## to read the banner, and fast enough that the banner is past the sun before
## the sun climbs to its height.
speed : F64
speed = 1.75

## How high the plane flies: its nose's height on the screen, the banner's
## middle, chosen by eye to sit well above the bird and the ridge.
cruise_y : F64
cruise_y = 54.0

## How far the plane bobs up and down, and how many steps one bob takes.
bob_height : F64
bob_height = 1.5

bob_steps : F64
bob_steps = 96.0

## How far behind the nose the banner's leading edge is, how long the banner
## is, and so how far behind the nose its tail reaches, all in pixels.
banner_front : F64
banner_front = 95.0

banner_length : F64
banner_length = 300.0

tail_reach : F64
tail_reach = banner_front + banner_length

## Half the banner's height.
banner_half_height : F64
banner_half_height = 15.0

## The banner's words, how tall their capitals stand, and how far in from the
## banner's tail they start, which centres them.
banner_words : Str
banner_words = "Welcome to Roc!"

letter_size : F64
letter_size = 18.0

letter_inset : F64
letter_inset = 18.0

## The ripple's height at the banner's tail, its wavelength along the banner,
## and how far it moves on each step, in radians.
ripple_height : F64
ripple_height = 2.5

ripple_length : F64
ripple_length = 120.0

ripple_speed : F64
ripple_speed = 0.2

body_color : RgbColor
body_color = RgbColor.of(0xD2402F)

wing_color : RgbColor
wing_color = RgbColor.of(0x9E2C22)

window_color : RgbColor
window_color = RgbColor.of(0xA8D4F0)

dark_color : RgbColor
dark_color = RgbColor.of(0x34343C)

banner_color : RgbColor
banner_color = RgbColor.of(0xFBF4DC)

hem_color : RgbColor
hem_color = RgbColor.of(0xD8C9A0)

letter_color : RgbColor
letter_color = RgbColor.of(0x5B2FB0)

## A point `dx` right of the nose and `dy` below it.
off_nose : Point, { dx : F64, dy : F64 } -> Point
off_nose = |nose, { dx, dy }| Point.at(nose.x.to_f64() + dx, nose.y.to_f64() + dy)

## The region round `offsets` from the nose, in one colour.
plane_part : Point, List((F64, F64)), Brush.Fill -> Shapes.Shape
plane_part = |nose, offsets, fill| Shapes.region_from_corners(offsets.map(|(dx, dy)| off_nose(nose, { dx, dy })), fill)

## A line a pixel or so wide between two points off the nose.
plane_line : Point, { from : (F64, F64), to : (F64, F64) } -> Shapes.Shape
plane_line = |nose, { from: (x0, y0), to: (x1, y1) }|
	Shapes.line(
		{ from: off_nose(nose, { dx: x0, dy: y0 }), to: off_nose(nose, { dx: x1, dy: y1 }), width: Pixels.of(1.2) },
		Brush.flat(dark_color),
	)

## The plane with its nose at `nose`: the tail fin, the body, the tailplane, the
## cabin's window, the wing above it and its strut, the wheel on its leg, and
## the spinning propeller as a pale blur.
plane_shapes : Point -> List(Shapes.Shape)
plane_shapes = |nose| {
	var $wheel_corners = List.with_capacity(8)
	for k in 0..<8 {
		angle = F64.tau * k.to_f64() / 8.0
		$wheel_corners = $wheel_corners.append((-15.0 + 2.4 * angle.cos(), 9.0 + 2.4 * angle.sin()))
	}
	wheel_corners = $wheel_corners
	[
		plane_part(nose, [(-40.0, -5.0), (-50.0, -15.0), (-55.0, -15.0), (-54.0, -3.0)], Brush.flat(wing_color)),
		plane_part(
			nose,
			[(0.0, -2.0), (-3.0, -5.0), (-9.0, -6.0), (-36.0, -5.0), (-52.0, -3.0), (-55.0, -1.0), (-52.0, 1.0), (-36.0, 3.0), (-8.0, 5.0), (-2.0, 4.0), (0.0, 2.0)],
			Brush.flat(body_color),
		),
		plane_part(nose, [(-44.0, -1.0), (-57.0, -2.0), (-57.0, 1.0), (-44.0, 1.0)], Brush.flat(wing_color)),
		plane_part(nose, [(-9.0, -5.0), (-19.0, -5.0), (-19.0, -1.0), (-7.0, -1.0)], Brush.flat(window_color)),
		plane_line(nose, { from: (-24.0, -6.0), to: (-17.0, 3.0) }),
		plane_part(nose, [(-9.0, -8.0), (-30.0, -8.0), (-31.0, -6.0), (-8.0, -6.0)], Brush.flat(wing_color)),
		plane_line(nose, { from: (-13.0, 4.0), to: (-15.0, 8.0) }),
		plane_part(nose, wheel_corners, Brush.flat(dark_color)),
		plane_part(nose, [(0.0, -2.0), (3.0, 0.0), (0.0, 2.0)], Brush.flat(dark_color)),
		plane_part(nose, [(1.0, -8.0), (2.5, -8.0), (2.5, 8.0), (1.0, 8.0)], Flat(Brush.with_alpha(RgbColor.of(0xE0E0E8), 0.55))),
	]
}

## The tow line from the plane's tail to a point short of the banner, and the
## two bridle lines from there to the banner's leading corners.
tow_line_shapes : Point -> List(Shapes.Shape)
tow_line_shapes = |nose| {
	bridle = (-(banner_front - 8.0), 0.0)
	[
		plane_line(nose, { from: (-57.0, 0.0), to: bridle }),
		plane_line(nose, { from: bridle, to: (-banner_front, -banner_half_height) }),
		plane_line(nose, { from: bridle, to: (-banner_front, banner_half_height) }),
	]
}

## How far the ripple lifts the banner `behind` pixels behind its leading edge:
## nothing at the edge, where the bar holds it, and most at the tail.
ripple_at : { behind : F64, steps : U64 } -> F64
ripple_at = |{ behind, steps }|
	ripple_height * behind / banner_length * (F64.tau * behind / ripple_length - steps.to_f64() * ripple_speed).sin()

## A point of the banner, moved up or down by the ripple where it is.
rippled_point : Point, { nose : Point, steps : U64 } -> Point
rippled_point = |point, { nose, steps }| {
	behind = nose.x.to_f64() - banner_front - point.x.to_f64()
	Point.at(point.x.to_f64(), point.y.to_f64() + ripple_at({ behind, steps }))
}

## The banner's strip, `half_height` either side of its middle, its top edge
## from the leading edge back and its bottom edge forward again, each moved by
## the ripple.
strip_shape : { nose : Point, steps : U64 }, { half_height : F64, color : RgbColor } -> Shapes.Shape
strip_shape = |flying, { half_height, color }| {
	samples = 29
	front = -banner_front
	var $corners = List.with_capacity(2 * (samples + 1))
	for k in 0..=samples {
		dx = front - banner_length * k.to_f64() / samples.to_f64()
		$corners = $corners.append(rippled_point(off_nose(flying.nose, { dx, dy: -half_height }), flying))
	}
	for k in 0..=samples {
		dx = front - banner_length * (samples - k).to_f64() / samples.to_f64()
		$corners = $corners.append(rippled_point(off_nose(flying.nose, { dx, dy: half_height }), flying))
	}
	Shapes.region_from_corners($corners, Brush.flat(color))
}

## A letter's stroke, its corners moved by the ripple. Font draws every stroke
## as a quad.
rippled_stroke : Shapes.Shape, { nose : Point, steps : U64 } -> Shapes.Shape
rippled_stroke = |shape, flying|
	match shape {
		Quad(q) =>
			Quad({
				..q,
				first: rippled_point(q.first, flying),
				second: rippled_point(q.second, flying),
				third: rippled_point(q.third, flying),
				fourth: rippled_point(q.fourth, flying),
			})
		_ => crash "BannerPlane.rippled_stroke: Font draws a stroke as a quad"
	}

## The banner: its darker hem, the pale strip inside it, the bar at its leading
## edge, and the words, all rippling together.
banner_shapes : { nose : Point, steps : U64 } -> List(Shapes.Shape)
banner_shapes = |flying| {
	hem = strip_shape(flying, { half_height: banner_half_height + 1.0, color: hem_color })
	strip = strip_shape(flying, { half_height: banner_half_height, color: banner_color })
	bar = plane_part(
		flying.nose,
		[(-banner_front, -banner_half_height - 1.0), (-banner_front + 2.0, -banner_half_height - 1.0), (-banner_front + 2.0, banner_half_height + 1.0), (-banner_front, banner_half_height + 1.0)],
		Brush.flat(dark_color),
	)
	words_top_left = off_nose(flying.nose, { dx: -tail_reach + letter_inset, dy: -letter_size / 2.0 })
	words = Font.text_shapes(banner_words, { top_left: words_top_left, size: letter_size, color: Brush.opaque_rgba(letter_color) })
	[hem, strip, bar].concat(words.map(|stroke| rippled_stroke(stroke, flying)))
}

# The plane is still to come a step before it enters, and draws nothing; at
# that step its nose is one step's flying into the sky, with the propeller's
# blur the only thing past it.
expect BannerPlane.flight_at(enters_step - 1) == Coming and BannerPlane.shapes_at(enters_step - 1) == []
expect
	match BannerPlane.flight_at(enters_step) {
		InView(nose) => nose.x.to_f64() == speed and !BannerPlane.shapes_at(enters_step).is_empty()
		_ => Bool.False
	}

# It enters at step 400 and is gone at step 1174, about 13.3 s and 39.1 s into
# the cycle's 45: in view on the step before, a pixel of the banner's tail
# still on the screen, and still gone at the cycle's last step.
expect enters_step == 400
expect
	match BannerPlane.flight_at(1173) {
		InView(nose) => nose.x.to_f64() - tail_reach < RoadCamera.screen_width
		_ => Bool.False
	}
expect BannerPlane.flight_at(1174) == Gone and BannerPlane.shapes_at(1174) == []
expect BannerPlane.flight_at(1349) == Gone

# The words fit on the banner with room either side. Font's width ends with a
# glyph's spacing, a third of the capitals' height, which no ink fills.
expect letter_inset + Font.width_of(banner_words, letter_size) - letter_size / 3.0 + letter_inset <= banner_length

# The ripple holds the leading edge still and lifts the tail by no more than
# its height.
expect ripple_at({ behind: 0.0, steps: 17 }) == 0.0
expect {
	var $highest = 0.0
	for steps in 0..<60 {
		$highest = $highest.max(ripple_at({ behind: banner_length, steps }).abs())
	}
	$highest <= ripple_height and $highest > ripple_height * 0.9
}
