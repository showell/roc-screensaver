## LanternsApp is the screensaver as a value a runner can play: the Roc bird
## hopping from lamp to lamp down a road that never ends, at sunrise, with the
## camera following it. It is made for Roc's 0.1.0 launch. Each lamp throws a
## pool of light on the road; the cycle opens at dawn with the sun behind the
## mountains, the sun peeks over them after three of the bird's crossings and
## climbs on, and the scene brightens all the way to the cycle's end, twenty
## crossings and a perch later, when it starts again from its first frame, so
## the cycle repeats exactly.
##
## A viewer may steer it with three keys, read from each step's input, so the
## page and a native window behave alike: Space pauses and resumes, R starts
## again at dawn, and the right arrow skips ahead one crossing. With no key
## struck it plays on by itself, as a screensaver must.
##
## The model is the scene and whether it is playing. The scene is one flight,
## how many steps into it the screensaver is, and how many steps into the
## cycle, so it stays the same size however long it plays.
## Each leg of the bird's journey is a perch, then a flight; when a leg
## ends, the next flight starts from the lamp the bird landed on. The camera
## moves down the road at one constant speed, the bird's own pace over a leg,
## so the bird draws ahead of it through each flight and it catches up through
## each perch.
import BannerPlane
import Bird
import BirdFlight
import JetFlyBy
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
	Model : { scene : LanternsApp.Scene, play : LanternsApp.Play }

	## Where the cycle has got to: everything a frame is drawn from.
	Scene : { flight : BirdFlight, steps_into_leg : U64, steps : U64 }

	## Whether the scene moves on at each step, or holds still for the viewer.
	Play : [Playing, Paused]

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
	frame_shapes = |model| {
		{ flight, steps_into_leg, steps } = model.scene
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
		# The jets are sorted by their distance too, so a lamp the camera is
		# passing paints over a jet farther off.
		drawn_jets = JetFlyBy.jets_at(steps)
		# Farthest first, so a nearer thing paints over a farther one.
		by_distance = drawn_lamps.concat(drawn_bird).concat(drawn_jets).sort_with(
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
		# The plane is in the sky beyond everything by the road, so a lamp near
		# enough to reach up to it paints over it.
		plane = BannerPlane.shapes_at(steps)
		backdrop_shapes(camera, light).concat(plane).concat(pools).concat(by_distance.join_map(|drawn| drawn.shapes))
	}
}

## How many steps the bird sits on its lamp before each flight, chosen by eye.
perch_steps : U64
perch_steps = 30

## How many steps a leg takes: the perch, then the flight.
leg_steps : U64
leg_steps = perch_steps + BirdFlight.frame_count

## The cycle runs over this many whole crossings, a leg each: about 45 s, short
## enough to watch it come round, long enough that the rise is not rushed.
rising_crossings : U64
rising_crossings = 20

## How many steps the cycle takes past its crossings: one perch, so the bird
## sits on its lamp at the end and the scene starts again just as it would
## take off.
closing_perch_steps : U64
closing_perch_steps = perch_steps

## How many steps the whole cycle takes: the crossings, then the closing perch.
cycle_steps : U64
cycle_steps = rising_crossings * leg_steps + closing_perch_steps

## The scene the cycle starts from, and starts again from each time round.
first_scene : LanternsApp.Scene
first_scene = { flight: BirdFlight.first, steps_into_leg: 0, steps: 0 }

## The model the screensaver starts from, playing, and the one R goes back to,
## so a restart plays at once even from a pause, as a viewer expects.
first_model : LanternsApp.Model
first_model = { scene: first_scene, play: Playing }

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

## The model after one step, given the keys. Each control reads a key struck
## at this step, never one held, so a held Space toggles once and a held right
## arrow skips once. R is read first, then Space, then the right arrow, so a
## step that strikes several does one thing. A step that skips or toggles
## does not also play a step.
model_at_next_step : LanternsApp.Model, Input.Snapshot -> LanternsApp.Model
model_at_next_step = |model, input|
	if input.key_pressed(KeyR) {
		first_model
	} else if input.key_pressed(KeySpace) {
		{ ..model, play: toggled(model.play) }
	} else if input.key_pressed(KeyRight) {
		# The skip plays a leg's steps, so the sun, the light and the bird all
		# move on together and the skip wraps where the cycle does. A paused
		# scene skips and stays paused.
		{ ..model, scene: scene_after(model.scene, leg_steps) }
	} else {
		match model.play {
			Playing => { ..model, scene: scene_at_next_step(model.scene) }
			Paused => model
		}
	}

toggled : LanternsApp.Play -> LanternsApp.Play
toggled = |play|
	match play {
		Playing => Paused
		Paused => Playing
	}

## The scene one step on: a step into the leg, the next leg from the lamp the
## bird landed on, or the cycle's first scene again after its last step.
scene_at_next_step : LanternsApp.Scene -> LanternsApp.Scene
scene_at_next_step = |scene| {
	steps_into_leg = scene.steps_into_leg + 1
	steps = scene.steps + 1
	if steps >= cycle_steps {
		first_scene
	} else if steps_into_leg >= leg_steps {
		{ flight: scene.flight.next(), steps_into_leg: 0, steps }
	} else {
		{ ..scene, steps_into_leg, steps }
	}
}

## The scene `count` steps on, played one at a time.
scene_after : LanternsApp.Scene, U64 -> LanternsApp.Scene
scene_after = |scene, count| {
	var $scene = scene
	for _k in 0..<count {
		$scene = scene_at_next_step($scene)
	}
	$scene
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
	after = scene_at_next_step(last_of_leg)
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
		{ flight, steps_into_leg, steps } = $model.scene
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

# The cycle is twenty legs and a closing perch, and it starts again from the
# first model on its last step and not a step before.
expect cycle_steps == 20 * 66 + 30
expect {
	last = { flight: BirdFlight.first, steps_into_leg: 29, steps: cycle_steps - 1 }
	scene_at_next_step(last) == first_scene
}
expect {
	before_last = { flight: BirdFlight.first, steps_into_leg: 28, steps: cycle_steps - 2 }
	after = scene_at_next_step(before_last)
	after.steps == cycle_steps - 1 and after.steps_into_leg == 29
}

# The controls. `mid` is a hundred steps in, partway through the second leg,
# and playing.
mid_model : LanternsApp.Model
mid_model = { scene: scene_after(first_scene, 100), play: Playing }

space : Input.Snapshot
space = Input.none.with_key_pressed(KeySpace)

# With no key struck the scene plays one step on, as it did before there were
# controls, and a held key that was not struck at this step changes nothing;
# a key the lanterns do not read is no key at all.
expect {
	stepped = { ..mid_model, scene: scene_at_next_step(mid_model.scene) }
	model_at_next_step(mid_model, Input.none) == stepped
		and stepped != mid_model
		and model_at_next_step(mid_model, Input.none.with_key_down(KeySpace)) == stepped
		and model_at_next_step(mid_model, Input.none.with_key_down(KeyR)) == stepped
		and model_at_next_step(mid_model, Input.none.with_key_down(KeyRight)) == stepped
		and model_at_next_step(mid_model, Input.none.with_key_pressed(KeyLeft)) == stepped
}

# Space pauses, holding the scene where it was, and a second Space resumes from
# exactly the model it paused, which then plays on.
expect {
	paused = model_at_next_step(mid_model, space)
	resumed = model_at_next_step(paused, space)
	paused.play == Paused
		and paused.scene == mid_model.scene
		and resumed == mid_model
		and model_at_next_step(resumed, Input.none).scene == scene_at_next_step(mid_model.scene)
}

# A paused step leaves the model as it was, for no key or a held Space.
expect {
	paused = { ..mid_model, play: Paused }
	model_at_next_step(paused, Input.none) == paused
		and model_at_next_step(paused, Input.none.with_key_down(KeySpace)) == paused
		and model_at_next_step(model_at_next_step(paused, Input.none), Input.none) == paused
}

# R goes back to the first model from mid-cycle, playing or paused, so a
# restart from a pause plays, and R at dawn stays at dawn; a held R does not
# restart again.
expect {
	r = Input.none.with_key_pressed(KeyR)
	model_at_next_step(mid_model, r) == first_model
		and model_at_next_step({ ..mid_model, play: Paused }, r) == first_model
		and model_at_next_step(first_model, r) == first_model
		and first_model.play == Playing
		and model_at_next_step(mid_model, Input.none.with_key_down(KeyR)) != first_model
}

# The right arrow moves the scene exactly one leg on, the bird one lamp
# further at the same point of its leg, playing or paused, and keeps the pause.
expect {
	right = Input.none.with_key_pressed(KeyRight)
	skipped = model_at_next_step(mid_model, right)
	paused_skip = model_at_next_step({ ..mid_model, play: Paused }, right)
	skipped.play == Playing
		and skipped.scene.steps == 166
		and skipped.scene.steps_into_leg == mid_model.scene.steps_into_leg
		and skipped.scene.flight == mid_model.scene.flight.next()
		and paused_skip.play == Paused
		and paused_skip.scene == skipped.scene
}

# A skip that passes the cycle's end wraps as the cycle does: from ten steps
# before the end it lands 56 steps into the first leg; from a leg before the
# end it lands on the first scene itself; from just over a leg before, a step
# short of it.
expect {
	right = Input.none.with_key_pressed(KeyRight)
	skip_from = |steps| model_at_next_step({ scene: scene_after(first_scene, steps), play: Playing }, right).scene
	near_end = skip_from(cycle_steps - 10)
	near_end.steps == 56
		and near_end.steps_into_leg == 56
		and near_end.flight == BirdFlight.first
		and skip_from(cycle_steps - leg_steps) == first_scene
		and skip_from(cycle_steps - leg_steps - 1).steps == cycle_steps - 1
}

# The day runs from 0 at dawn and grows at every step, up to the last.
expect day_at(0) == Fraction.zero
# Sunrise's expects pin the sun's first peek and its clearing at steps of a
# 1350-step cycle, which is the day this one gives at those steps.
expect day_at(199) == Fraction.of(199.0 / 1350.0) and day_at(765) == Fraction.of(765.0 / 1350.0)
expect day_at(cycle_steps / 2) == Fraction.of(0.5)
expect day_at(cycle_steps - 2) < day_at(cycle_steps - 1) and day_at(cycle_steps - 1) != Fraction.whole

# Through the whole cycle the banner plane, whenever it is in view, stays
# above the top of the bird's drawing by at least 20 pixels and clear of the
# sun's disc, on the screen's top; it is in view for 774 steps, from step 400
# to 1173.
expect {
	var $model = first_model
	var $in_view = 0
	var $touches = 0
	var $first_in_view = cycle_steps
	var $last_in_view = 0
	for _step in 0..<cycle_steps {
		steps = $model.scene.steps
		plane_corners = BannerPlane.shapes_at(steps).join_map(|shape| Shapes.region_corners(shape) ?? crash "every part of the plane has corners")
		if !plane_corners.is_empty() {
			left = plane_corners.fold(1.0e9, |a, c| a.min(c.x.to_f64()))
			right = plane_corners.fold(-1.0e9, |a, c| a.max(c.x.to_f64()))
			top = plane_corners.fold(1.0e9, |a, c| a.min(c.y.to_f64()))
			bottom = plane_corners.fold(-1.0e9, |a, c| a.max(c.y.to_f64()))
			bird_clear =
				match bird_drawing_top($model.scene) {
					Top(bird_top) => bottom + 20.0 < bird_top
					Unseen => Bool.True
				}
			sun = Sunrise.light_at(day_at(steps)).sun_center
			r = Sunrise.sun_radius.to_f64()
			sun_clear = bottom < sun.y.to_f64() - r or top > sun.y.to_f64() + r or right < sun.x.to_f64() - r or left > sun.x.to_f64() + r
			$in_view = $in_view + 1
			$first_in_view = $first_in_view.min(steps)
			$last_in_view = $last_in_view.max(steps)
			$touches =
				if bird_clear and sun_clear and top >= 0.0 {
					$touches
				} else {
					$touches + 1
				}
		} else {
			{}
		}
		$model = model_at_next_step($model, Input.none)
	}
	$touches == 0 and $in_view == 774 and $first_in_view == 400 and $last_in_view == 1173
}

# Through the whole cycle the jets fly from step 1276 to 1339, five of them at
# every step of it, ten steps before the rewind. All of their drawing, their
# trails too, stays at least 20 pixels above the top of the bird's drawing and
# above the far range's highest peak, so they never cross the bird or the
# mountains, and some of it is on the screen at every step.
expect {
	ridge_top = Sunrise.far_range.fold(1.0e9, |a, c| a.min(c.y.to_f64()))
	var $model = first_model
	var $in_view = 0
	var $fives = 0
	var $touches = 0
	var $first_in_view = cycle_steps
	var $last_in_view = 0
	for _step in 0..<cycle_steps {
		steps = $model.scene.steps
		jets = JetFlyBy.jets_at(steps)
		if !jets.is_empty() {
			jet_shapes = jets.join_map(|jet| jet.shapes)
			corners = jet_shapes.join_map(|shape| Shapes.region_corners(shape) ?? crash "every part of a jet has corners")
			bottom = corners.fold(-1.0e9, |a, c| a.max(c.y.to_f64()))
			on_screen = corners.any(|c| c.x.to_f64() >= 0.0 and c.x.to_f64() <= RoadCamera.screen_width and c.y.to_f64() >= 0.0)
			bird_clear =
				match bird_drawing_top($model.scene) {
					Top(bird_top) => bottom + 20.0 < bird_top
					Unseen => Bool.True
				}
			$in_view = $in_view + 1
			$first_in_view = $first_in_view.min(steps)
			$last_in_view = $last_in_view.max(steps)
			$fives =
				if jets.len() == 5 {
					$fives + 1
				} else {
					$fives
				}
			$touches =
				if bird_clear and bottom < ridge_top and on_screen {
					$touches
				} else {
					$touches + 1
				}
		} else {
			{}
		}
		$model = model_at_next_step($model, Input.none)
	}
	$touches == 0 and $in_view == 64 and $fives == 64
		and $first_in_view == 1276 and $last_in_view == 1339
}

# The jets are in the frame while they fly.
expect {
	jet_shapes = JetFlyBy.jets_at(1300).join_map(|jet| jet.shapes)
	frame = LanternsApp.frame_shapes({ scene: scene_after(first_scene, 1300), play: Playing })
	jet_shapes.len() == 25 and jet_shapes.all(|shape| frame.contains(shape))
}

## How high on the screen the top of the bird's drawing reaches in `scene`, the
## highest its pose reaches, or `Unseen` when the bird is behind the camera.
bird_drawing_top : LanternsApp.Scene -> [Top(F64), Unseen]
bird_drawing_top = |{ flight, steps_into_leg, steps }| {
	camera = camera_at(steps)
	bird = flight.bird_instant_at(flight_stage(steps_into_leg))
	gap = bird.location.along - camera.along()
	bird_corners = Bird.pose_still(bird.pose).polygons().join_map(|polygon| polygon.points)
	bird_rise = bird_corners.fold(0.0, |most, corner| most.max(corner.y))
	bird_height = RoadCamera.size_on_screen({ height: Bird.height_metres, forward: gap }).to_f64()
	match camera.project(bird.location) {
		Ok(foot) => Top(foot.y.to_f64() - bird_height * bird_rise)
		Err(BehindCamera) => Unseen
	}
}

# The plane is in the frame while it is in view, and a skip from before it
# enters brings it in.
expect {
	plane = BannerPlane.shapes_at(700)
	frame = LanternsApp.frame_shapes({ scene: scene_after(first_scene, 700), play: Playing })
	plane.len() > 20 and plane.all(|shape| frame.contains(shape))
}
expect {
	right = Input.none.with_key_pressed(KeyRight)
	before = { scene: scene_after(first_scene, 380), play: Playing }
	skipped = model_at_next_step(before, right)
	BannerPlane.flight_at(before.scene.steps) == Coming and BannerPlane.flight_at(skipped.scene.steps) != Coming
}

# A frame draws the backdrop, the lamps, their pools and the bird.
expect LanternsApp.frame_shapes({ scene: { flight: BirdFlight.first, steps_into_leg: 40, steps: 40 }, play: Playing }).len() > 50
