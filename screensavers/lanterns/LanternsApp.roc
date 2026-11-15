## LanternsApp is the screensaver as a value a runner can play: the Roc bird
## hopping from lamp to lamp down a road at dusk that never ends, with the
## camera following it. The sun sets behind the mountains, each lamp throws a
## pool of light on the road, fireflies drift over the verges, and a soft light
## stays on the bird wherever it goes. It needs no input.
##
## The model is one flight, how many steps into it the screensaver is, and how
## many steps it has run in all, so it stays the same size however long it
## plays. Each leg of the bird's journey is a perch, then a flight; when a leg
## ends, the next flight starts from the lamp the bird landed on. The camera
## closes on the perched bird, easing in and to a stop, then follows it across
## with the flight's own easing as the bird draws away from it.
import Bird
import BirdFlight
import Easing
import LampShapes
import RoadCamera
import RoadLamps
import StillOnScreen
import lib.Brush
import lib.CanvasApp
import lib.Fraction
import lib.Input
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes

LanternsApp :: [].{
	Model : { flight : BirdFlight, steps_into_leg : U64, steps : U64 }

	canvas_app : CanvasApp.CanvasApp(LanternsApp.Model)
	canvas_app = {
		size: { width: RoadCamera.screen_width, height: RoadCamera.screen_height },
		# Safari's motion is written per step at thirty steps a second, and the
		# flight is Safari's, so it plays at the same rate.
		frames_a_second: 30,
		init: { flight: BirdFlight.first, steps_into_leg: 0, steps: 0 },
		model_at_next_step: CanvasApp.untimed_model_at_next_step(model_at_next_step),
		frame_shapes: LanternsApp.frame_shapes,
		sounds: |_model| 0,
		tones: [],
		title: "Lanterns",
	}

	frame_shapes : LanternsApp.Model -> List(Shapes.Shape)
	frame_shapes = |{ flight, steps_into_leg, steps }| {
		camera = camera_at(flight, steps_into_leg)
		lamps = RoadLamps.lamps_between({
			nearest: camera.along() + RoadCamera.near_plane,
			farthest: camera.along() + view_depth,
		})
		drawn_lamps = lamps.keep_oks(|lamp| drawn_lamp(camera, lamp))
		bird = flight.bird_instant_at(flight_stage(steps_into_leg))
		drawn_bird = drawn_bird_of(camera, { bird, flight })
		# Farthest first, so a nearer thing paints over a farther one.
		by_distance = drawn_lamps.concat(fireflies(camera, steps)).concat(drawn_bird).sort_with(
			|a, b|
				if a.forward > b.forward {
					Before
				} else if a.forward < b.forward {
					After
				} else {
					Same
				},
		)
		pools = lamps.join_map(|lamp| light_pool(camera, lamp))
		backdrop_shapes(camera).concat(pools).concat(by_distance.join_map(|drawn| drawn.shapes))
	}
}

## How many steps the bird sits on its lamp before each flight, chosen by eye.
perch_steps : U64
perch_steps = 30

## How many steps a leg takes: the perch, then the flight.
leg_steps : U64
leg_steps = perch_steps + BirdFlight.frame_count

## How far behind the bird's lamp the camera is as a leg starts, chosen by eye.
follow_distance : F64
follow_distance = 30.0

## How far the camera closes on the perched bird before it takes off, chosen
## by eye.
perch_approach : F64
perch_approach = 8.0

## How far ahead of the camera a lamp is still drawn.
view_depth : F64
view_depth = 400.0

model_at_next_step : LanternsApp.Model, Input.Snapshot -> LanternsApp.Model
model_at_next_step = |model, _input| {
	steps_into_leg = model.steps_into_leg + 1
	steps = model.steps + 1
	if steps_into_leg >= leg_steps {
		{ flight: model.flight.next(), steps_into_leg: 0, steps }
	} else {
		{ ..model, steps_into_leg, steps }
	}
}

## Where the flight has got to `steps_into_leg` steps into its leg.
flight_stage : U64 -> BirdFlight.Stage
flight_stage = |steps_into_leg|
	if steps_into_leg < perch_steps {
		Waiting
	} else {
		Playing(steps_into_leg - perch_steps)
	}

## The camera `steps_into_leg` steps into the leg of `flight`. Through the
## perch it eases from `follow_distance` behind the lamp the bird leaves to
## `perch_approach` nearer; through the flight it eases on to `follow_distance`
## behind the lamp the bird lands on. It stops at each end of each part, so its
## pace never jumps.
camera_at : BirdFlight, U64 -> RoadCamera
camera_at = |flight, steps_into_leg| {
	{ from, to } = flight.lamps()
	start = from.along - follow_distance
	at_takeoff = start + perch_approach
	along =
		match flight_stage(steps_into_leg) {
			Waiting => {
				through = Fraction.of(steps_into_leg.to_f64() / perch_steps.to_f64())
				start + perch_approach * Easing.smoothstep(through).to_f64()
			}
			Playing(steps_in) => {
				finish = to.along - follow_distance
				at_takeoff + (finish - at_takeoff) * BirdFlight.eased_share_at(steps_in)
			}
		}
	RoadCamera.at({ along, across: 0.0 })
}

## One thing by the road, drawn by its distance from the camera.
Drawn : { forward : F64, shapes : List(Shapes.Shape) }

## A lamp on the screen, if it is in front of the camera.
drawn_lamp : RoadCamera, RoadLamps.RoadLamp -> Try(Drawn, [BehindCamera])
drawn_lamp = |camera, lamp| {
	foot = camera.project({ along: lamp.along, across: lamp.across, lift: 0.0 })?
	forward = camera.forward_of(lamp.along)
	height_on_screen = RoadCamera.size_on_screen({ height: lamp.lantern.height_metres(), forward })
	Ok({ forward, shapes: LampShapes.lamp_shapes({ foot, height_on_screen }, lamp.lantern) })
}

## The bird on the screen, if it is in front of the camera, as a list of none
## or one: the soft light that keeps it the brightest thing in view, then the
## bird.
drawn_bird_of : RoadCamera, { bird : BirdFlight.BirdInstant, flight : BirdFlight } -> List(Drawn)
drawn_bird_of = |camera, { bird, flight }|
	match camera.project(bird.location) {
		Err(BehindCamera) => []
		Ok(foot) => {
			forward = camera.forward_of(bird.location.along)
			height_on_screen = RoadCamera.size_on_screen({ height: Bird.height_metres, forward })
			anchor = {
				foot,
				flip: Bird.pose_flip(bird.pose, flight.heading()),
				height_on_screen,
			}
			light = Shapes.halo(
				{
					center: { x: foot.x, y: foot.y.minus(height_on_screen.times(0.45)) },
					radius: height_on_screen.times(1.15),
				},
				Brush.with_alpha(RgbColor.of(0xFFF4DC), 0.45),
			)
			# A lamp is drawn flat, as wide at the bird's depth as at its own, so
			# the two lamps of a flight would hide a bird that is above their
			# tops. The bird is drawn just nearer than both.
			{ from, to } = flight.lamps()
			nearest = forward.min(camera.forward_of(from.along)).min(camera.forward_of(to.along))
			[{ forward: nearest - 0.01, shapes: [light].concat(StillOnScreen.still_shapes(anchor, Bird.pose_still(bird.pose))) }]
		}
	}

## How far a lamp's pool of light spreads on the ground, in metres, chosen by
## eye.
pool_radius : F64
pool_radius = 3.2

## The pool of light a lamp throws on the ground: the circle round its foot,
## seen through the camera, lit brightest at the foot and fading to nothing at
## its edge. None for a pool any of whose edge is behind the camera.
light_pool : RoadCamera, RoadLamps.RoadLamp -> List(Shapes.Shape)
light_pool = |camera, lamp| {
	sides = 20
	var $corners = List.with_capacity(sides)
	for k in 0..<sides {
		angle = F64.tau * k.to_f64() / sides.to_f64()
		rim_point = camera.project({
			along: lamp.along + pool_radius * angle.sin(),
			across: lamp.across + pool_radius * angle.cos(),
			lift: 0.0,
		})
		$corners =
			match rim_point {
				Ok(corner) => $corners.append(corner)
				Err(BehindCamera) => $corners
			}
	}
	corners = $corners
	if corners.len() < sides {
		[]
	} else {
		xs = corners.map(|p| p.x.to_f64())
		ys = corners.map(|p| p.y.to_f64())
		least_x = xs.fold(1.0e9, |a, x| a.min(x))
		most_x = xs.fold(-1.0e9, |a, x| a.max(x))
		least_y = ys.fold(1.0e9, |a, y| a.min(y))
		most_y = ys.fold(-1.0e9, |a, y| a.max(y))
		glow = lamp.lantern.glow_color()
		look = {
			stops: {
				start_color: Brush.with_alpha(glow, 0.5),
				end_color: Brush.with_alpha(glow, 0.0),
				start_offset: 0.0,
				end_offset: 1.0,
			},
			center: Point.at((least_x + most_x) / 2.0, (least_y + most_y) / 2.0),
			axis_u: Point.at((most_x - least_x) / 2.0, 0.0),
			axis_v: Point.at(0.0, (most_y - least_y) / 2.0),
		}
		match Brush.elliptical_gradient(look) {
			Ok(fill) => [Polygon({ corners, fill })]
			Err(TooThin) => []
		}
	}
}

## How far apart the fireflies' places are along the road, chosen by eye.
firefly_spacing : F64
firefly_spacing = 5.0

## How far ahead of the camera the fireflies are drawn.
firefly_reach : F64
firefly_reach = 90.0

## The fireflies over the verges near the camera. Each has a place along the
## road that never moves, so the camera passes them, and drifts and blinks on
## its own beat, drawn from its place.
fireflies : RoadCamera, U64 -> List(Drawn)
fireflies = |camera, steps| {
	seconds = steps.to_f64() / 30.0
	first = ((camera.along() + 2.0) / firefly_spacing).floor_to_i64_try() ?? 0
	count = (firefly_reach / firefly_spacing).floor_to_u64_try() ?? 0
	var $drawn = []
	for k in 0..<count {
		cell = first + k.to_i64_wrap()
		# A cell behind the road's start is negative, so its key keeps the
		# low 32 bits, as every draw's does.
		key = cell.to_u64_wrap().bitwise_and(4294967295)
		phase = unit_draw(key * 3) * F64.tau
		side = if unit_draw(key * 3 + 1) < 0.5 {
			-1.0
		} else {
			1.0
		}
		out = 5.0 + 7.0 * unit_draw(key * 5 + 1)
		home = (cell.to_f64() + unit_draw(key * 3 + 2)) * firefly_spacing
		along = home + 2.0 * (seconds * 0.6 + phase).sin()
		location = {
			along,
			across: side * out + 0.6 * (seconds * 0.8 + phase).cos(),
			lift: 1.2 + 0.7 * (seconds * 0.5 + phase * 2.0).sin(),
		}
		blink = (seconds * 1.7 + phase).sin()
		$drawn =
			match camera.project(location) {
				Ok(center) if blink > -0.3 => {
					forward = camera.forward_of(along)
					radius = RoadCamera.size_on_screen({ height: 0.09, forward }).max(Pixels.of(1.2))
					alpha = (0.3 + 0.7 * blink).max(0.15).min(1.0)
					$drawn.append({ forward, shapes: [Disc({ center, radius, fill: Flat(Brush.with_alpha(RgbColor.of(0xF2FF8C), alpha)) })] })
				}
				_ => $drawn
			}
	}
	$drawn
}

## A number from 0 up to 1 drawn for `key`, as RoadLamps draws its nudges.
unit_draw : U64 -> F64
unit_draw = |key| {
	mask = 4294967295
	turn = |n| (n.bitwise_and(mask) * 1664525 + 1013904223).bitwise_and(mask)
	turn(turn(turn(key + 7919))).shr_wrap(8).to_f64() / 16777216.0
}

## The dusk: a sky going from deep blue to the sunset's orange, as the basic
## example's was.
sky_top : RgbColor
sky_top = RgbColor.of(0x2A3F7A)

sky_horizon : RgbColor
sky_horizon = RgbColor.of(0xF2A65A)

grass_near : RgbColor
grass_near = RgbColor.of(0x1B2918)

grass_far : RgbColor
grass_far = RgbColor.of(0x37472F)

road_color : RgbColor
road_color = RgbColor.of(0x4A4650)

line_color : RgbColor
line_color = RgbColor.of(0xE8DDB8)

road_half_width : F64
road_half_width = 2.0

## The mountains' outlines along the horizon, left to right, chosen by eye: a
## far range with the sun going down into its notch, and nearer hills.
far_range : List(Point)
far_range = [
	Point.at(0.0, 250.0),
	Point.at(120.0, 200.0),
	Point.at(250.0, 238.0),
	Point.at(400.0, 150.0),
	Point.at(560.0, 232.0),
	Point.at(690.0, 188.0),
	Point.at(820.0, 258.0),
	Point.at(960.0, 205.0),
	Point.at(960.0, RoadCamera.horizon_y + 1.0),
	Point.at(0.0, RoadCamera.horizon_y + 1.0),
]

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

## Where the sun sits, half down behind the far range, and how big it is.
sun_center : Point
sun_center = Point.at(612.0, 226.0)

sun_radius : Pixels
sun_radius = Pixels.of(38.0)

## The sky, the sun and its glow, the mountains, the grass, the road to the
## horizon, and the dashes down its middle.
backdrop_shapes : RoadCamera -> List(Shapes.Shape)
backdrop_shapes = |camera| {
	sky = Shapes.rectangle({
		top_left: Point.at(0.0, 0.0),
		width: Pixels.of(RoadCamera.screen_width),
		height: Pixels.of(RoadCamera.horizon_y + 1.0),
		fill: Brush.linear_gradient({
			stops: {
				start_color: Brush.opaque_rgba(sky_top),
				end_color: Brush.opaque_rgba(sky_horizon),
				start_offset: 0.2,
				end_offset: 1.0,
			},
			start_point: Point.at(0.0, 0.0),
			end_point: Point.at(0.0, RoadCamera.horizon_y),
		}),
	})
	sun_glow = Shapes.halo({ center: sun_center, radius: Pixels.of(300.0) }, Brush.with_alpha(RgbColor.of(0xFFC980), 0.6))
	sun = Disc({
		center: sun_center,
		radius: sun_radius,
		fill: Radial({
			inner_color: Brush.opaque_rgba(RgbColor.of(0xFFE6A3)),
			outer_color: Brush.opaque_rgba(RgbColor.of(0xFF9D5C)),
			center: sun_center,
			inner_radius: Pixels.zero,
			outer_radius: sun_radius,
		}),
	})
	far = Polygon({ corners: far_range, fill: Brush.corners_shade(far_range, { color: RgbColor.of(0x5E5778), strength: Fraction.of(0.6) }) })
	near_fill = Brush.corners_shade(near_hills, { color: RgbColor.of(0x46553A), strength: Fraction.of(0.8) })
	hills = Polygon({ corners: near_hills, fill: near_fill })
	grass = Shapes.rectangle({
		top_left: Point.at(0.0, RoadCamera.horizon_y),
		width: Pixels.of(RoadCamera.screen_width),
		height: Pixels.of(RoadCamera.screen_height - RoadCamera.horizon_y),
		fill: Brush.linear_gradient({
			stops: {
				start_color: Brush.opaque_rgba(grass_far),
				end_color: Brush.opaque_rgba(grass_near),
				start_offset: 0.0,
				end_offset: 1.0,
			},
			start_point: Point.at(0.0, RoadCamera.horizon_y),
			end_point: Point.at(0.0, RoadCamera.screen_height),
		}),
	})
	near = camera.along() + 1.5
	far_along = camera.along() + 5000.0
	road = ground_quad(camera, { near, far: far_along, left: 0.0 - road_half_width, right: road_half_width }, road_color)
	[sky, sun_glow, sun, far, hills, grass].concat(road).concat(dash_shapes(camera))
}

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
	first_dash = (camera.along() / dash_spacing).floor_to_i64_try() ?? crash "LanternsApp.dash_shapes: a road longer than an I64 of dashes"
	count = (dash_reach / dash_spacing).floor_to_u64_try() ?? crash "LanternsApp.dash_shapes: a reach that is no count of dashes"
	var $shapes = []
	for k in 0..<count {
		start = (first_dash + k.to_i64_wrap()).to_f64() * dash_spacing
		near = start.max(camera.along() + 1.5)
		far = start + dash_length
		if far > near {
			$shapes = $shapes.concat(ground_quad(camera, { near, far, left: -0.08, right: 0.08 }, line_color))
		} else {
			{}
		}
	}
	$shapes
}

## A flat stretch of ground from `near` to `far` along the road and from
## `left` to `right` across it, as one quad, or none if any corner is behind the
## camera.
ground_quad : RoadCamera,
{
	near : F64,
	far : F64,
	left : F64,
	right : F64,
},
RgbColor -> List(Shapes.Shape)
ground_quad = |camera, { near, far, left, right }, color| {
	corner = |along, across| camera.project({ along, across, lift: 0.0 })
	corners = [corner(near, left), corner(far, left), corner(far, right), corner(near, right)]
	match corners {
		[Ok(first), Ok(second), Ok(third), Ok(fourth)] => [Quad({ first, second, third, fourth, fill: Brush.flat(color) })]
		_ => []
	}
}

# A leg is a perch, then a flight, and the next leg starts from where the
# bird landed.
expect flight_stage(0) == Waiting and flight_stage(perch_steps - 1) == Waiting
expect flight_stage(perch_steps) == Playing(0)
expect flight_stage(leg_steps - 1) == Playing(BirdFlight.frame_count - 1)
expect {
	last_of_leg = { flight: BirdFlight.first, steps_into_leg: leg_steps - 1, steps: 99 }
	after = model_at_next_step(last_of_leg, Input.none)
	after.steps_into_leg == 0 and after.flight == BirdFlight.first.next() and after.steps == 100
}

# The camera ends a leg where it starts the next, so it never jumps.
expect {
	flight = BirdFlight.first
	{ to, .. } = flight.lamps()
	last_of_leg = camera_at(flight, leg_steps - 1).along()
	last_of_leg == to.along - follow_distance and camera_at(flight.next(), 0).along() == last_of_leg
}

# A frame draws the backdrop, the lamps, their pools and the bird.
expect LanternsApp.frame_shapes({ flight: BirdFlight.first, steps_into_leg: 40, steps: 40 }).len() > 50
