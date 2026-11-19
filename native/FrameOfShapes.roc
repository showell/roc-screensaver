## FrameOfShapes turns a canvas app's frame, a list of lib's shapes, into the
## native platform's Frame, so one app's Roc paints on a canvas and through
## host/raster.zig alike. Each brush becomes the Frame fill that paints the
## same colours wherever the two can, and the README's "The adapter" lists the
## few places they can't.
##
## The shapes are the whole picture. A canvas app paints its own sky, so the
## frame's background is plain black with no sun, and only shows where the
## shapes leave the screen bare.
import pf.Frame
import lib.Brush
import lib.Fraction
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes
import lib.WidthShading

FrameOfShapes :: [].{

	## The frame that paints `shapes` in order.
	frame_of : List(Shapes.Shape) -> Frame
	frame_of = |shapes| {
		background: bare_background,
		shapes: shapes.join_map(frame_shapes_of),
	}

	## The frame shapes one shape becomes: none, one, or two halves of a
	## region whose brush raster.zig can only paint in two parts.
	frame_shapes_of : Shapes.Shape -> List(Frame.Shape)
	frame_shapes_of = |shape|
		match shape {
			Triangle(t) => region_shapes([t.first, t.second, t.third], t.fill)
			Quad(q) => region_shapes([q.first, q.second, q.third, q.fourth], q.fill)
			Polygon(p) => region_shapes(p.corners, p.fill)
			Disc(d) => disc_shapes(d)
			# raster.zig only paints over, so light that adds is painted over too.
			Blend(_) => []
			View(Screen) => []
			View(World(_)) => crash "FrameOfShapes: a World view has no native counterpart yet"
			Image(_) => crash "FrameOfShapes: an image has no native counterpart"
			Text(_) => crash "FrameOfShapes: a line of type has no native counterpart"
		}
}

bare_background : Frame.Background
bare_background = {
	sky_top: 0x000000,
	sky_horizon: 0x000000,
	roll: 0.0,
	sun: Hidden,
}

## A point as the frame takes it.
frame_point : Point -> Frame.Point
frame_point = |point| { x: point.x.to_f64().to_f32_wrap(), y: point.y.to_f64().to_f32_wrap() }

## One colour channel, 0..255, as a whole byte, rounded half up as a canvas
## rounds it.
byte_of : F64 -> U32
byte_of = |value| {
	held = value.max(0.0).min(255.0)
	rounded = (held + 0.5).floor_to_u64_try() ?? crash "FrameOfShapes.byte_of: a channel is a finite number"
	rounded.to_u32_wrap()
}

## An opaque colour, `0xRRGGBB`, from a brush's colour, its alpha left out.
rgb_of : Brush.Rgba -> Frame.Rgb
rgb_of = |c| byte_of(c.r) * 65536 + byte_of(c.g) * 256 + byte_of(c.b)

## A colour with its alpha, `0xAARRGGBB`.
argb_of : Brush.Rgba -> Frame.Argb
argb_of = |c| byte_of(c.a * 255.0) * 16777216 + rgb_of(c)

## A gradient's colour where its stops put it, as BrushShade.shade gives it.
color_at_stop : Brush.TwoStops, F64 -> Brush.Rgba
color_at_stop = |stops, t|
	if t <= stops.start_offset {
		stops.start_color
	} else if t >= stops.end_offset {
		stops.end_color
	} else {
		Brush.mix({
			from: stops.start_color,
			to: stops.end_color,
			fraction: (t - stops.start_offset) / (stops.end_offset - stops.start_offset),
		})
	}

## The frame's two stops for a brush's. raster.zig clamps an offset into
## 0..1 and keeps the colour, where a brush takes the colour the gradient has
## at that end, so an offset past an end becomes a stop at the end in that
## colour.
frame_stops : Brush.TwoStops -> { start : Frame.Stop, end : Frame.Stop }
frame_stops = |stops| {
	start =
		if stops.start_offset < 0.0 {
			{ color: argb_of(color_at_stop(stops, 0.0)), at: 0.0 }
		} else {
			{ color: argb_of(stops.start_color), at: stops.start_offset.min(1.0).to_f32_wrap() }
		}
	end =
		if stops.end_offset > 1.0 {
			{ color: argb_of(color_at_stop(stops, 1.0)), at: 1.0 }
		} else {
			{ color: argb_of(stops.end_color), at: stops.end_offset.max(0.0).to_f32_wrap() }
		}
	{ start, end }
}

## The region round `corners` in one colour, translucent or not.
flat_shapes : List(Frame.Point), Brush.Rgba -> List(Frame.Shape)
flat_shapes = |points, color|
	if color.a <= 0.0 {
		[]
	} else if color.a >= 1.0 {
		[Polygon({ points, fill: Solid(rgb_of(color)) })]
	} else {
		# raster.zig's only translucent fills are gradients, and a gradient
		# whose two stops are one colour is that colour everywhere.
		stop = { color: argb_of(color), at: 0.0 }
		[
			Polygon({
				points,
				fill: Linear({ from: { x: 0.0, y: 0.0 }, to: { x: 1.0, y: 0.0 }, start: stop, end: { ..stop, at: 1.0 } }),
			}),
		]
	}

## The region round `corners`, filled with `fill`.
region_shapes : List(Point), Brush.Fill -> List(Frame.Shape)
region_shapes = |corners, fill| {
	points = corners.map(frame_point)
	match fill {
		Flat(color) => flat_shapes(points, color)
		Span(span) => span_shapes(points, span)
		Radial(r) => {
			inner = r.inner_radius.to_f64()
			outer = r.outer_radius.to_f64()
			center = frame_point(r.center)
			if outer <= inner or outer < 0.5 {
				# With no ring to walk, or one too small to see, a brush gives
				# the outer colour everywhere.
				flat_shapes(points, r.outer_color)
			} else if inner <= 0.0 {
				[
					Polygon({
						points,
						fill: Radial({ center, radius: outer.to_f32_wrap(), inner: argb_of(r.inner_color), outer: argb_of(r.outer_color) }),
					}),
				]
			} else {
				# raster.zig's radial starts at the centre, and its ellipse
				# takes a first stop part way out, so a ring is a round ellipse.
				radius = outer.to_f32_wrap()
				[
					Polygon({
						points,
						fill: Elliptical({
							center,
							u: { x: radius, y: 0.0 },
							v: { x: 0.0, y: radius },
							start: { color: argb_of(r.inner_color), at: (inner / outer).to_f32_wrap() },
							end: { color: argb_of(r.outer_color), at: 1.0 },
						}),
					}),
				]
			}
		}
		Linear(l) => {
			from = frame_point(l.start_point)
			to = frame_point(l.end_point)
			dx = l.end_point.x.to_f64() - l.start_point.x.to_f64()
			dy = l.end_point.y.to_f64() - l.start_point.y.to_f64()
			if dx * dx + dy * dy <= 0.0 {
				flat_shapes(points, color_at_stop(l.stops, 1.0))
			} else {
				{ start, end } = frame_stops(l.stops)
				[Polygon({ points, fill: Linear({ from, to, start, end }) })]
			}
		}
		Ellipse(e) => {
			{ start, end } = frame_stops(e.stops)
			[
				Polygon({
					points,
					fill: Elliptical({ center: frame_point(e.center), u: frame_point(e.axis_u), v: frame_point(e.axis_v), start, end }),
				}),
			]
		}
		Glow(g) =>
		# raster.zig's gradients have two stops, so a glow's middle stop is
		# left out: it runs straight from its inner colour to its outer.
			region_shapes(
				corners,
				Radial({
					inner_color: g.inner_color,
					outer_color: g.outer_color,
					center: g.center,
					inner_radius: g.inner_radius,
					outer_radius: g.outer_radius,
				}),
			)
	}
}

## A span's brush across the region round `points`. raster.zig's round fill
## is a span from the region's own left edge to its right, made from one
## colour and a strength, so a span that WidthShading.width_shade made over the
## region's own width is painted as one. Any other span is painted in two
## halves, each a linear gradient from the edge colour to the middle one.
span_shapes : List(Frame.Point),
{
	edge_color : Brush.Rgba,
	middle_color : Brush.Rgba,
	left_x : Pixels,
	right_x : Pixels,
} -> List(Frame.Shape)
span_shapes = |points, span| {
	left = span.left_x.to_f64()
	right = span.right_x.to_f64()
	if right <= left {
		# A brush whose edges meet gives its edge colour everywhere.
		flat_shapes(points, span.edge_color)
	} else {
		match round_of(points, span) {
			Ok(round) => [Polygon({ points, fill: Round(round) })]
			Err(NotRound) => {
				middle = (left + right) / 2.0
				edge = argb_of(span.edge_color)
				mid = argb_of(span.middle_color)
				left_half = clipped_points(points, { x: middle.to_f32_wrap(), keep: Below })
				right_half = clipped_points(points, { x: middle.to_f32_wrap(), keep: Above })
				half = |half_points, from_x, to_x, start, end|
					if half_points.len() < 3 {
						[]
					} else {
						[
							Polygon({
								points: half_points,
								fill: Linear({
									from: { x: from_x.to_f32_wrap(), y: 0.0 },
									to: { x: to_x.to_f32_wrap(), y: 0.0 },
									start: { color: start, at: 0.0 },
									end: { color: end, at: 1.0 },
								}),
							}),
						]
					}
				half(left_half, left, middle, edge, mid).concat(half(right_half, middle, right, mid, edge))
			}
		}
	}
}

## The round fill that paints `span` over the region round `points`, when the
## span covers the region's own width and both its colours are opaque. Its
## colour and strength are read back from the span's edge and middle colours,
## which width_shade made as the colour darkened by 0.4 of the strength and
## lightened by 0.25 of it, so they come back within a level of rounding.
round_of : List(Frame.Point),
{
	edge_color : Brush.Rgba,
	middle_color : Brush.Rgba,
	left_x : Pixels,
	right_x : Pixels,
} -> Try({ color : Frame.Rgb, strength : F32 }, [NotRound])
round_of = |points, span| {
	xs = points.map(|p| p.x.to_f64())
	least = xs.fold(span.right_x.to_f64(), |a, x| a.min(x))
	most = xs.fold(span.left_x.to_f64(), |a, x| a.max(x))
	edge = span.edge_color
	middle = span.middle_color
	covers = (least - span.left_x.to_f64()).abs() < 0.5 and (most - span.right_x.to_f64()).abs() < 0.5
	if !covers or edge.a < 1.0 or middle.a < 1.0 {
		Err(NotRound)
	} else {
		# The brightest edge channel whose middle is not held at 255 gives the
		# truest ratio.
		pairs = [(edge.r, middle.r), (edge.g, middle.g), (edge.b, middle.b)].keep_if(|(e, m)| e >= 1.0 and m < 254.5)
		brightest = pairs.fold(
			(0.0, 0.0),
			|(be, bm), (e, m)| if e > be {
				(e, m)
			} else {
				(be, bm)
			},
		)
		(e, m) = brightest
		if e < 1.0 {
			Err(NotRound)
		} else {
			k = m / e
			strength = (k - 1.0) / (0.25 + 0.4 * k)
			if strength <= 0.0 or strength > 1.0 {
				Err(NotRound)
			} else {
				base = |channel| channel / (1.0 - 0.4 * strength)
				Ok({
					color: rgb_of({ r: base(edge.r), g: base(edge.g), b: base(edge.b), a: 1.0 }),
					strength: strength.to_f32_wrap(),
				})
			}
		}
	}
}

## The part of the region round `points` on one side of the upright line at
## `x`: Sutherland and Hodgman's clip against one half-plane. A region that is
## not convex may come back with edges along the line, which a scanline fill
## paints as nothing.
clipped_points : List(Frame.Point), { x : F32, keep : [Below, Above] } -> List(Frame.Point)
clipped_points = |points, { x, keep }| {
	inside = |p|
		match keep {
			Below => p.x <= x
			Above => p.x >= x
		}
	crossing = |a, b| {
		t = (x - a.x) / (b.x - a.x)
		{ x, y: a.y + t * (b.y - a.y) }
	}
	count = points.len()
	var $out = []
	for k in 0..<count {
		a = points.get(k) ?? crash "FrameOfShapes.clipped_points: a corner within the count"
		b = points.get((k + 1) % count) ?? crash "FrameOfShapes.clipped_points: a corner within the count"
		$out =
			match (inside(a), inside(b)) {
				(Bool.True, Bool.True) => $out.append(b)
				(Bool.True, Bool.False) => $out.append(crossing(a, b))
				(Bool.False, Bool.True) => $out.append(crossing(a, b)).append(b)
				(Bool.False, Bool.False) => $out
			}
	}
	$out
}

## How many sides a disc's polygon takes: enough that its edge strays from
## the circle by under a quarter of a pixel.
disc_sides : F64 -> U64
disc_sides = |radius| {
	wanted = (radius * 0.6).floor_to_u64_try() ?? 64
	wanted.max(12).min(96)
}

## A disc: raster.zig's own disc for a flat colour, and otherwise the polygon
## round it, filled with the brush.
disc_shapes : { center : Point, radius : Pixels, fill : Brush.Fill } -> List(Frame.Shape)
disc_shapes = |{ center, radius, fill }|
	match fill {
		Flat(color) =>
			if color.a <= 0.0 {
				[]
			} else {
				[Disc({ center: frame_point(center), radius: radius.to_f64().to_f32_wrap(), color: rgb_of(color), alpha: color.a.min(1.0).to_f32_wrap() })]
			}
		_ => {
			r = radius.to_f64()
			cx = center.x.to_f64()
			cy = center.y.to_f64()
			sides = disc_sides(r)
			var $corners = List.with_capacity(sides)
			for k in 0..<sides {
				angle = F64.tau * k.to_f64() / sides.to_f64()
				$corners = $corners.append(Point.at(cx + r * angle.cos(), cy + r * angle.sin()))
			}
			region_shapes($corners, fill)
		}
	}

white : Brush.Rgba
white = { r: 255.0, g: 255.0, b: 255.0, a: 1.0 }

square : List(Point)
square = [Point.at(0.0, 0.0), Point.at(10.0, 0.0), Point.at(10.0, 10.0), Point.at(0.0, 10.0)]

# A flat colour is solid when opaque, a one-colour gradient when translucent,
# and nothing when unseen.
expect region_shapes(square, Flat(white)).len() == 1
expect
	match region_shapes(square, Flat({ ..white, a: 0.5 })) {
		[Polygon({ fill: Linear(l), .. })] => l.start.color == 0x80FFFFFF and l.end.color == 0x80FFFFFF
		_ => Bool.False
	}
expect region_shapes(square, Flat({ ..white, a: 0.0 })) == []

# A width-shaded span over the region's own width comes back as the colour and
# strength width_shade made it from, each channel within a level: 0x804020
# comes back as 0x804120, since width_shade rounded the green it shaded.
expect {
	span = WidthShading.width_shade({ min_x: Pixels.of(0.0), max_x: Pixels.of(10.0) }, { color: RgbColor.of(0x804020), strength: Fraction.of(0.8) })
	match region_shapes(square, span) {
		[Polygon({ fill: Round(r), .. })] => r.color == 0x804120 and (r.strength - 0.8).abs() < 0.01
		_ => Bool.False
	}
}

# A span over another width is two halves, each a linear gradient.
expect {
	span = WidthShading.width_shade({ min_x: Pixels.of(0.0), max_x: Pixels.of(20.0) }, { color: RgbColor.of(0x804020), strength: Fraction.of(0.8) })
	match region_shapes(square, span) {
		[Polygon({ fill: Linear(_), .. }), Polygon({ fill: Linear(_), .. })] => Bool.True
		_ => Bool.False
	}
}

# A square cut at x = 5 keeps the corners on its side and two on the line.
expect clipped_points(square.map(frame_point), { x: 5.0, keep: Below }) == [{ x: 5.0, y: 0.0 }, { x: 5.0, y: 10.0 }, { x: 0.0, y: 10.0 }, { x: 0.0, y: 0.0 }]

# An offset past an end becomes a stop at that end, in the colour there.
expect {
	black = { ..white, r: 0.0, g: 0.0, b: 0.0 }
	{ start, end } = frame_stops({ start_color: black, end_color: white, start_offset: -1.0, end_offset: 1.0 })
	start == { color: 0xFF808080, at: 0.0 } and end == { color: 0xFFFFFFFF, at: 1.0 }
}

# A flat disc is raster.zig's own disc, and a gradient disc a polygon.
expect
	match disc_shapes({ center: Point.at(1.0, 2.0), radius: Pixels.of(3.0), fill: Flat({ ..white, a: 0.5 }) }) {
		[Disc(d)] => d.alpha == 0.5 and d.color == 0xFFFFFF
		_ => Bool.False
	}
