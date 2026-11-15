## LanternsApp is the screensaver as a value a runner can play: the Roc bird
## hopping from lamp to lamp down a road that never ends, at sunrise, with the
## camera following it. It is made for Roc's 0.1.0 launch. Each lamp throws a
## pool of light on the road; the cycle opens at dawn with the sun behind the
## mountains, the sun peeks over them after three of the bird's crossings and
## climbs on, and the scene brightens all the way to the cycle's end, thirteen
## crossings and a perch later, when it starts again from its first frame, so
## the cycle repeats exactly. It needs no input.
##
## The model is one flight, how many steps into it the screensaver is, and how
## many steps into the cycle, so it stays the same size however long it plays.
## Each leg of the bird's journey is a perch, then a flight; when a leg
## ends, the next flight starts from the lamp the bird landed on. The camera
## moves down the road at one constant speed, the bird's own pace over a leg,
## so the bird draws ahead of it through each flight and it catches up through
## each perch.
import Bird
import BirdFlight
import LampShapes
import RoadCamera
import RoadLamps
import StillOnScreen
import Sunrise
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
		init: first_model,
		model_at_next_step: CanvasApp.untimed_model_at_next_step(model_at_next_step),
		frame_shapes: LanternsApp.frame_shapes,
		sounds: |_model| 0,
		tones: [],
		title: "Lanterns",
		controls: [
			{ keys: "Space", does: "pauses and resumes" },
			{ keys: "R", does: "restarts at dawn" },
			{ keys: "→", does: "skips ahead a crossing" },
		],
	}

	frame_shapes : LanternsApp.Model -> List(Shapes.Shape)
	frame_shapes = |{ flight, steps_into_leg, steps }| {
		camera = camera_at(steps)
		day = day_at(steps)
		light = Sunrise.light_at(day)
		lamps = RoadLamps.lamps_between({
			nearest: camera.along() + RoadCamera.near_plane,
			farthest: camera.along() + view_depth,
		})
		drawn_lamps = lamps.keep_oks(|lamp| drawn_lamp(camera, { lamp, day }))
		bird = flight.bird_instant_at(flight_stage(steps_into_leg))
		drawn_bird = drawn_bird_of(camera, { bird, flight })
		# Farthest first, so a nearer thing paints over a farther one.
		by_distance = drawn_lamps.concat(drawn_bird).sort_with(
			|a, b|
				if a.forward > b.forward {
					Before
				} else if a.forward < b.forward {
					After
				} else {
					Same
				},
		)
		pools = lamps.join_map(|lamp| light_pool(camera, { lamp, day }))
		backdrop_shapes(camera, light).concat(pools).concat(by_distance.join_map(|drawn| drawn.shapes))
	}
}

## How many steps the bird sits on its lamp before each flight, chosen by eye.
perch_steps : U64
perch_steps = 30

## How many steps a leg takes: the perch, then the flight.
leg_steps : U64
leg_steps = perch_steps + BirdFlight.frame_count

## The cycle runs over this many whole crossings, a leg each: about 30 s, short
## enough to watch it come round, long enough that the rise is not rushed.
rising_crossings : U64
rising_crossings = 13

## How many steps the cycle takes past its crossings: one perch, so the bird
## sits on its lamp at the end and the scene starts again just as it would
## take off.
closing_perch_steps : U64
closing_perch_steps = perch_steps

## How many steps the whole cycle takes: the crossings, then the closing perch.
cycle_steps : U64
cycle_steps = rising_crossings * leg_steps + closing_perch_steps

## The model the screensaver starts from, and starts again from each cycle.
first_model : LanternsApp.Model
first_model = { flight: BirdFlight.first, steps_into_leg: 0, steps: 0 }

## How far into the day it is `steps` into the cycle: 0 at dawn as the cycle
## starts, then a little more at every step to the last, so the scene never
## stops brightening before it starts again.
day_at : U64 -> Fraction
day_at = |steps| Fraction.clamp(steps.to_f64() / cycle_steps.to_f64())

## How far the camera moves down the road each step: one lamp spacing a leg,
## which is the bird's pace, since every flight is one place on.
camera_speed : F64
camera_speed = RoadLamps.lamp_spacing / leg_steps.to_f64()

## How far behind the even place of the bird's lamp the camera is as each leg
## starts, just as the bird lands, chosen by eye. Through the perch the camera
## closes by a perch's worth of its speed (about 14 m), so the bird takes off
## about 20 m ahead, as near as is comfortable to look at; a lamp's nudge moves
## either by up to 6 m.
follow_distance : F64
follow_distance = 34.0

## How far ahead of the camera a lamp is still drawn.
view_depth : F64
view_depth = 400.0

model_at_next_step : LanternsApp.Model, Input.Snapshot -> LanternsApp.Model
model_at_next_step = |model, _input| {
	steps_into_leg = model.steps_into_leg + 1
	steps = model.steps + 1
	if steps >= cycle_steps {
		first_model
	} else if steps_into_leg >= leg_steps {
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

## The camera `steps` into the cycle: `follow_distance` behind the first
## lamp's even place as the cycle starts, then on at `camera_speed`.
camera_at : U64 -> RoadCamera
camera_at = |steps| RoadCamera.at({ along: RoadLamps.even_along(0) - follow_distance + camera_speed * steps.to_f64(), across: 0.0 })

## One thing by the road, drawn by its distance from the camera.
Drawn : { forward : F64, shapes : List(Shapes.Shape) }

## A lamp on the screen, if it is in front of the camera.
drawn_lamp : RoadCamera, { lamp : RoadLamps.RoadLamp, day : Fraction } -> Try(Drawn, [BehindCamera])
drawn_lamp = |camera, { lamp, day }| {
	foot = camera.project({ along: lamp.along, across: lamp.across, lift: 0.0 })?
	forward = camera.forward_of(lamp.along)
	height_on_screen = RoadCamera.size_on_screen({ height: lamp.lantern.height_metres(), forward })
	Ok({ forward, shapes: LampShapes.lamp_shapes({ foot, height_on_screen }, { lantern: lamp.lantern, day }) })
}

## The bird on the screen, if it is in front of the camera, as a list of none
## or one.
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
			# A lamp is drawn flat, as wide at the bird's depth as at its own, so
			# the two lamps of a flight would hide a bird that is above their
			# tops. The bird is drawn just nearer than both.
			{ from, to } = flight.lamps()
			nearest = forward.min(camera.forward_of(from.along)).min(camera.forward_of(to.along))
			[{ forward: nearest - 0.01, shapes: StillOnScreen.still_shapes(anchor, Bird.pose_still(bird.pose)) }]
		}
	}

## How far a lamp's pool of light spreads on the ground, in metres, chosen by
## eye.
pool_radius : F64
pool_radius = 3.2

## The pool of light a lamp throws on the ground: the circle round its foot,
## seen through the camera, lit brightest at the foot and fading to nothing at
## its edge, strongest at dawn and fainter as the day comes up. None for a pool any of
## whose edge is behind the camera.
light_pool : RoadCamera, { lamp : RoadLamps.RoadLamp, day : Fraction } -> List(Shapes.Shape)
light_pool = |camera, { lamp, day }| {
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
				start_color: Brush.with_alpha(glow, 0.56 - 0.24 * day.to_f64()),
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
	far = Polygon({ corners: Sunrise.far_range, fill: Brush.corners_shade(Sunrise.far_range, { color: light.far_range, strength: Fraction.of(0.6) }) })
	near_fill = Brush.corners_shade(near_hills, { color: light.hills, strength: Fraction.of(0.8) })
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
	road = ground_quad(camera, { near, far: far_along, left: 0.0 - road_half_width, right: road_half_width }, light.road)
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

# Through the whole cycle the bird stays between 12 m and 45 m ahead of the
# camera, and all of its drawing, the widest and tallest its pose reaches either
# way, stays on the screen; and the cycle ends on the first model again.
expect {
	var $model = first_model
	var $nearest = 1000.0
	var $farthest = 0.0
	var $off_screen = 0
	for _step in 0..<cycle_steps {
		{ flight, steps_into_leg, steps } = $model
		camera = camera_at(steps)
		bird = flight.bird_instant_at(flight_stage(steps_into_leg))
		gap = bird.location.along - camera.along()
		$nearest = $nearest.min(gap)
		$farthest = $farthest.max(gap)
		corners = Bird.pose_still(bird.pose).polygons().join_map(|polygon| polygon.points)
		top = corners.fold(0.0, |most, corner| most.max(corner.y))
		half_width = corners.fold(0.0, |most, corner| most.max(corner.x.abs()))
		height = RoadCamera.size_on_screen({ height: Bird.height_metres, forward: gap }).to_f64()
		$off_screen =
			match camera.project(bird.location) {
				Ok(foot) if foot.x.to_f64() - height * half_width >= 0.0 and foot.x.to_f64() + height * half_width <= RoadCamera.screen_width and foot.y.to_f64() - height * top >= 0.0 and foot.y.to_f64() <= RoadCamera.screen_height => $off_screen
				_ => $off_screen + 1
			}
		$model = model_at_next_step($model, Input.none)
	}
	$nearest >= 12.0 and $farthest <= 45.0 and $off_screen == 0 and $model == first_model
}

# The camera keeps one speed, and is the same at the start of each cycle.
expect (camera_at(leg_steps).along() - camera_at(0).along() - RoadLamps.lamp_spacing).abs() < 1.0e-9
expect (camera_at(2 * leg_steps).along() - camera_at(leg_steps).along() - RoadLamps.lamp_spacing).abs() < 1.0e-9
expect camera_at(0).along() == RoadLamps.even_along(0) - follow_distance

# The cycle is thirteen legs and a closing perch, and it starts again from the
# first model on its last step and not a step before.
expect cycle_steps == 13 * 66 + 30
expect {
	last = { flight: BirdFlight.first, steps_into_leg: 29, steps: cycle_steps - 1 }
	model_at_next_step(last, Input.none) == first_model
}
expect {
	before_last = { flight: BirdFlight.first, steps_into_leg: 28, steps: cycle_steps - 2 }
	after = model_at_next_step(before_last, Input.none)
	after.steps == cycle_steps - 1 and after.steps_into_leg == 29
}

# The day runs from 0 at dawn and grows at every step, up to the last.
expect day_at(0) == Fraction.zero
expect day_at(cycle_steps / 2) == Fraction.of(0.5)
expect day_at(cycle_steps - 2) < day_at(cycle_steps - 1) and day_at(cycle_steps - 1) != Fraction.whole

# A frame draws the backdrop, the lamps, their pools and the bird.
expect LanternsApp.frame_shapes({ flight: BirdFlight.first, steps_into_leg: 40, steps: 40 }).len() > 50
