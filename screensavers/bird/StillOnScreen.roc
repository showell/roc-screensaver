## StillOnScreen draws a still, a sprite made of polygons, standing on screen.
## A still is drawn in its own frame, which Still.roc describes. StillOnScreen
## scales it to its height on screen, stands it on its feet, and mirrors it when
## asked.
##
## This file is adapted from roc-apps (`canvas_apps/safari/StillShapes.roc`) on
## 2026-11-15, and it is allowed to drift from it. The drawing is Safari's,
## copied; the anchor is handed in whole, because this screensaver's camera is
## its own, and there is no night to dim a still for.
import Still
import lib.Brush
import lib.Pixels
import lib.Point
import lib.Shapes

StillOnScreen :: [].{

	## Which way a still is drawn: as its polygons are, or mirrored left to
	## right.
	Flip : [AsDrawn, Mirrored]

	## Where a still stands on screen: its foot, which way it is drawn, and
	## its height on screen.
	Anchor : {
		foot : Point,
		flip : StillOnScreen.Flip,
		height_on_screen : Pixels,
	}

	## Where a point of the still lands on screen: the foot, and the point's
	## step from it.
	screen_point : StillOnScreen.Anchor, Still.FramePoint -> Point
	screen_point = |anchor, point| {
		step = screen_vector(anchor, point)
		{ x: anchor.foot.x.plus(step.x), y: anchor.foot.y.plus(step.y) }
	}

	## A whole still, its polygons in order.
	still_shapes : StillOnScreen.Anchor, Still -> List(Shapes.Shape)
	still_shapes = |anchor, still|
		still.polygons().map(|polygon| still_polygon(anchor, polygon))
}

## The sign that a still's x is multiplied by.
x_sign : StillOnScreen.Flip -> F64
x_sign = |flip|
	match flip {
		AsDrawn => 1.0
		Mirrored => -1.0
	}

## How far, and which way, a step in the still goes on screen.
screen_vector : StillOnScreen.Anchor, Still.FrameVector -> Point
screen_vector = |anchor, step| {
	x: anchor.height_on_screen.times(x_sign(anchor.flip) * step.x),
	y: anchor.height_on_screen.times(step.y).opposite(),
}

## One polygon of a still, filled with its colour or its gradient.
still_polygon : StillOnScreen.Anchor, Still.Polygon -> Shapes.Shape
still_polygon = |anchor, polygon| {
	points = polygon.points.map(|point| StillOnScreen.screen_point(anchor, point))
	match polygon.fill {
		Flat(color) => Shapes.region_from_corners(points, Brush.flat(color))
		Shaded(gradient) => still_gradient_polygon(anchor, { gradient, points })
	}
}

still_gradient_polygon : StillOnScreen.Anchor,
{
	gradient : Still.Gradient,
	points : List(Point),
} -> Shapes.Shape
still_gradient_polygon = |anchor, { gradient, points }|
	match gradient {
		Linear({ stops, start, end }) => {
			fill = Brush.linear_gradient({
				stops: brush_stops(stops),
				start_point: StillOnScreen.screen_point(anchor, start),
				end_point: StillOnScreen.screen_point(anchor, end),
			})
			Shapes.region_from_corners(points, fill)
		}
		Radial({ stops, center, axis_u, axis_v }) => {
			ellipse = Brush.elliptical_gradient({
				stops: brush_stops(stops),
				center: StillOnScreen.screen_point(anchor, center),
				axis_u: screen_vector(anchor, axis_u),
				axis_v: screen_vector(anchor, axis_v),
			})
			fill =
				match ellipse {
					Ok(gradient_fill) => gradient_fill
					Err(TooThin) => crash "StillOnScreen.still_gradient_polygon: an ellipse too thin for Brush to invert"
				}
			Shapes.region_from_corners(points, fill)
		}
	}

## A still's colour stops as a brush takes them.
brush_stops : Still.ColorStops -> Brush.TwoStops
brush_stops = |stops| {
	start_color: Brush.translucent(stops.start_color),
	end_color: Brush.translucent(stops.end_color),
	start_offset: stops.start_offset.to_f64(),
	end_offset: stops.end_offset.to_f64(),
}

sample_foot : Point
sample_foot = Point.at(100.0, 200.0)

# A still 50 pixels tall, standing on the foot, as drawn.
upright : StillOnScreen.Anchor
upright = {
	foot: sample_foot,
	flip: AsDrawn,
	height_on_screen: Pixels.of(50.0),
}

# The same still, mirrored.
mirrored : StillOnScreen.Anchor
mirrored = {
	foot: sample_foot,
	flip: Mirrored,
	height_on_screen: Pixels.of(50.0),
}

expect StillOnScreen.screen_point(upright, { x: 0.5, y: 0.4 }) == Point.at(125.0, 180.0)
expect StillOnScreen.screen_point(mirrored, { x: 0.5, y: 0.4 }) == Point.at(75.0, 180.0)
expect StillOnScreen.screen_point(upright, { x: 0.0, y: 0.0 }) == Point.at(100.0, 200.0)
