## BackdropShapes is the land behind the lamps and the bird, in the cycle's
## light: the sky, the sun and its glow, the far range the sun rises from, the
## nearer hills, the grass, and the road running to the horizon with the dashes
## down its middle. The road and its dashes are seen through the camera, so
## they move as it does; the rest stands still on the screen.
import RoadCamera
import Sunrise
import lib.Brush
import lib.Fraction
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes
import lib.WidthShading

BackdropShapes :: [].{

	## The sky, the sun and its glow, the far range the sun rises from, the hills,
	## the grass, the road to the horizon, and the dashes down its middle, all in
	## the cycle's `light`.
	backdrop_shapes : RoadCamera, Sunrise.Light -> List(Shapes.Shape)
	backdrop_shapes = |camera, light| {
		sky = Shapes.rectangle({
			top_left: Point.at(0.0, 0.0),
			width: Pixels.of(RoadCamera.screen_width),
			height: Pixels.of(RoadCamera.horizon_y + 1.0),
			fill: Brush.linear_gradient({
				stops: {
					start_color: Brush.opaque_rgba(light.sky_top),
					end_color: Brush.opaque_rgba(light.sky_horizon),
					start_offset: 0.2,
					end_offset: 1.0,
				},
				start_point: Point.at(0.0, 0.0),
				end_point: Point.at(0.0, RoadCamera.horizon_y),
			}),
		})
		sun_center = light.sun_center
		sun_glow = Shapes.halo({ center: sun_center, radius: Pixels.of(300.0) }, Brush.with_alpha(light.sun_glow, light.sun_glow_alpha))
		sun = Disc({
			center: sun_center,
			radius: Sunrise.sun_radius,
			fill: Radial({
				inner_color: Brush.opaque_rgba(light.sun_inner),
				outer_color: Brush.opaque_rgba(light.sun_outer),
				center: sun_center,
				inner_radius: Pixels.zero,
				outer_radius: Sunrise.sun_radius,
			}),
		})
		# The far range is drawn over the sun, so the sun goes down behind its ridge.
		far = Polygon({ corners: Sunrise.far_range_corners, fill: WidthShading.corners_shade(Sunrise.far_range_corners, { color: light.far_range, strength: Fraction.of(0.6) }) })
		near_fill = WidthShading.corners_shade(near_hills, { color: light.hills, strength: Fraction.of(0.8) })
		hills = Polygon({ corners: near_hills, fill: near_fill })
		grass = Shapes.rectangle({
			top_left: Point.at(0.0, RoadCamera.horizon_y),
			width: Pixels.of(RoadCamera.screen_width),
			height: Pixels.of(RoadCamera.screen_height - RoadCamera.horizon_y),
			fill: Brush.linear_gradient({
				stops: {
					start_color: Brush.opaque_rgba(light.grass_far),
					end_color: Brush.opaque_rgba(light.grass_near),
					start_offset: 0.0,
					end_offset: 1.0,
				},
				start_point: Point.at(0.0, RoadCamera.horizon_y),
				end_point: Point.at(0.0, RoadCamera.screen_height),
			}),
		})
		near = camera.along() + 1.5
		far_along = camera.along() + 5000.0
		road = ground_quad_shapes(camera, { near, far: far_along, left: 0.0 - road_half_width, right: road_half_width }, light.road)
		[sky, sun_glow, sun, far, hills, grass].concat(road).concat(dash_shapes(camera))
	}
}

line_color : RgbColor
line_color = RgbColor.of(0xE8DDB8)

road_half_width : F64
road_half_width = 2.0

## The nearer hills' outline along the horizon, left to right, chosen by eye.
near_hills : List(Point)
near_hills = [
	Point.at(0.0, 330.0),
	Point.at(150.0, 300.0),
	Point.at(300.0, 346.0),
	Point.at(470.0, 312.0),
	Point.at(640.0, 352.0),
	Point.at(800.0, 306.0),
	Point.at(960.0, 336.0),
	Point.at(960.0, RoadCamera.horizon_y + 1.0),
	Point.at(0.0, RoadCamera.horizon_y + 1.0),
]

## How far apart the middle line's dashes start, and how long each is.
dash_spacing : F64
dash_spacing = 9.0

dash_length : F64
dash_length = 3.0

## How far ahead of the camera the middle line is drawn.
dash_reach : F64
dash_reach = 240.0

## The dashes down the middle of the road between the camera and `dash_reach`.
dash_shapes : RoadCamera -> List(Shapes.Shape)
dash_shapes = |camera| {
	first_dash = (camera.along() / dash_spacing).floor_to_i64_try() ?? crash "BackdropShapes.dash_shapes: a road longer than an I64 of dashes"
	count = (dash_reach / dash_spacing).floor_to_u64_try() ?? crash "BackdropShapes.dash_shapes: a reach that is no count of dashes"
	var $shapes = []
	for k in 0..<count {
		start = (first_dash + k.to_i64_wrap()).to_f64() * dash_spacing
		near = start.max(camera.along() + 1.5)
		far = start + dash_length
		if far > near {
			$shapes = $shapes.concat(ground_quad_shapes(camera, { near, far, left: -0.08, right: 0.08 }, line_color))
		} else {
			{}
		}
	}
	$shapes
}

## A flat stretch of ground from `near` to `far` along the road and from
## `left` to `right` across it, as one quad, or none if any corner is behind the
## camera.
ground_quad_shapes : RoadCamera,
{
	near : F64,
	far : F64,
	left : F64,
	right : F64,
},
RgbColor -> List(Shapes.Shape)
ground_quad_shapes = |camera, { near, far, left, right }, color| {
	corner = |along, across| camera.project({ along, across, lift: 0.0 })
	corners = [corner(near, left), corner(far, left), corner(far, right), corner(near, right)]
	match corners {
		[Ok(first), Ok(second), Ok(third), Ok(fourth)] => [Quad({ first, second, third, fourth, fill: Brush.flat(color) })]
		_ => []
	}
}
