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
## The model is the scene and whether it is playing. SceneCycle says what the
## scene is and how it moves on; BackdropShapes draws the land behind it, and
## RoadsideShapes the lamps, their pools and the bird.
import BackdropShapes
import BannerPlane
import Bird
import BirdFlight
import JetFlyBy
import RoadCamera
import RoadLamps
import RoadsideShapes
import SceneCycle
import Sunrise
import lib.CanvasApp
import lib.Input
import lib.Shapes

LanternsApp :: [].{
	Model : { scene : SceneCycle.Scene, play : LanternsApp.Play }

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
		camera = SceneCycle.camera_at(steps)
		day = SceneCycle.day_at(steps)
		light = Sunrise.light_at(day)
		lamps = RoadLamps.lamps_between({
			nearest: camera.along() + RoadCamera.near_plane,
			farthest: camera.along() + view_depth,
		})
		drawn_lamps = lamps.keep_oks(|lamp| RoadsideShapes.drawn_lamp(camera, { lamp, day }))
		bird = flight.bird_instant_at(SceneCycle.flight_stage(steps_into_leg))
		drawn_bird = RoadsideShapes.drawn_birds(camera, { bird, flight })
		# The jets are sorted by their distance too, so a lamp the camera is
		# passing paints over a jet farther off.
		drawn_jets = JetFlyBy.jets_at(steps)
		# Farthest first, so a nearer thing paints over a farther one.
		by_distance = drawn_lamps.concat(drawn_bird).concat(drawn_jets).sort_with(
			|first, second|
				if first.forward > second.forward {
					Before
				} else if first.forward < second.forward {
					After
				} else {
					Same
				},
		)
		pools = lamps.join_map(|lamp| RoadsideShapes.light_pool_shapes(camera, { lamp, day }))
		# The plane is in the sky beyond everything by the road, so a lamp near
		# enough to reach up to it paints over it.
		plane = BannerPlane.shapes_at(steps)
		BackdropShapes.backdrop_shapes(camera, light).concat(plane).concat(pools).concat(by_distance.join_map(|drawn| drawn.shapes))
	}
}

## The model the screensaver starts from, playing, and the one R goes back to,
## so a restart plays at once even from a pause, as a viewer expects.
first_model : LanternsApp.Model
first_model = { scene: SceneCycle.first_scene, play: Playing }

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
		{ ..model, play: other_play(model.play) }
	} else if input.key_pressed(KeyRight) {
		# The skip plays a leg's steps, so the sun, the light and the bird all
		# move on together and the skip wraps where the cycle does. A paused
		# scene skips and stays paused.
		{ ..model, scene: SceneCycle.scene_after(model.scene, SceneCycle.leg_steps) }
	} else {
		match model.play {
			Playing => { ..model, scene: SceneCycle.scene_at_next_step(model.scene) }
			Paused => model
		}
	}

## The play a toggle gives: paused from playing, playing from paused.
other_play : LanternsApp.Play -> LanternsApp.Play
other_play = |play|
	match play {
		Playing => Paused
		Paused => Playing
	}

# The controls. `mid` is a hundred steps in, partway through the second leg,
# and playing.
mid_model : LanternsApp.Model
mid_model = { scene: SceneCycle.scene_after(SceneCycle.first_scene, 100), play: Playing }

space : Input.Snapshot
space = Input.none.with_key_pressed(KeySpace)

# With no key struck the scene plays one step on, as it did before there were
# controls, and a held key that was not struck at this step changes nothing;
# a key the lanterns do not read is no key at all.
expect {
	stepped = { ..mid_model, scene: SceneCycle.scene_at_next_step(mid_model.scene) }
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
		and model_at_next_step(resumed, Input.none).scene == SceneCycle.scene_at_next_step(mid_model.scene)
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
	r_key = Input.none.with_key_pressed(KeyR)
	model_at_next_step(mid_model, r_key) == first_model
		and model_at_next_step({ ..mid_model, play: Paused }, r_key) == first_model
		and model_at_next_step(first_model, r_key) == first_model
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
	skip_from = |steps| model_at_next_step({ scene: SceneCycle.scene_after(SceneCycle.first_scene, steps), play: Playing }, right).scene
	near_end = skip_from(SceneCycle.cycle_steps - 10)
	near_end.steps == 56
		and near_end.steps_into_leg == 56
		and near_end.flight == BirdFlight.first
		and skip_from(SceneCycle.cycle_steps - SceneCycle.leg_steps) == SceneCycle.first_scene
		and skip_from(SceneCycle.cycle_steps - SceneCycle.leg_steps - 1).steps == SceneCycle.cycle_steps - 1
}

# Through the whole cycle the banner plane, whenever it is in view, stays
# above the top of the bird's drawing by at least 20 pixels and clear of the
# sun's disc, on the screen's top; it is in view for 774 steps, from step 400
# to 1173.
expect {
	var $model = first_model
	var $in_view = 0
	var $touches = 0
	var $first_in_view = SceneCycle.cycle_steps
	var $last_in_view = 0.U64
	for _step in 0..<SceneCycle.cycle_steps {
		steps = $model.scene.steps
		plane_corners = BannerPlane.shapes_at(steps).join_map(|shape| Shapes.region_corners(shape) ?? crash "every part of the plane has corners")
		if !plane_corners.is_empty() {
			left = plane_corners.fold(1.0e9, |least, corner| least.min(corner.x.to_f64()))
			right = plane_corners.fold(-1.0e9, |most, corner| most.max(corner.x.to_f64()))
			top = plane_corners.fold(1.0e9, |least, corner| least.min(corner.y.to_f64()))
			bottom = plane_corners.fold(-1.0e9, |most, corner| most.max(corner.y.to_f64()))
			bird_clear =
				match bird_drawing_top($model.scene) {
					Top(bird_top) => bottom + 20.0 < bird_top
					Unseen => Bool.True
				}
			sun = Sunrise.light_at(SceneCycle.day_at(steps)).sun_center
			sun_radius = Sunrise.sun_radius.to_f64()
			sun_clear = bottom < sun.y.to_f64() - sun_radius or top > sun.y.to_f64() + sun_radius or right < sun.x.to_f64() - sun_radius or left > sun.x.to_f64() + sun_radius
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
	ridge_top = Sunrise.far_range_corners.fold(1.0e9, |least, corner| least.min(corner.y.to_f64()))
	var $model = first_model
	var $in_view = 0
	var $fives = 0
	var $touches = 0
	var $first_in_view = SceneCycle.cycle_steps
	var $last_in_view = 0.U64
	for _step in 0..<SceneCycle.cycle_steps {
		steps = $model.scene.steps
		jets = JetFlyBy.jets_at(steps)
		if !jets.is_empty() {
			jet_shapes = jets.join_map(|jet| jet.shapes)
			corners = jet_shapes.join_map(|shape| Shapes.region_corners(shape) ?? crash "every part of a jet has corners")
			bottom = corners.fold(-1.0e9, |most, corner| most.max(corner.y.to_f64()))
			on_screen = corners.any(|corner| corner.x.to_f64() >= 0.0 and corner.x.to_f64() <= RoadCamera.screen_width and corner.y.to_f64() >= 0.0)
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
	frame = LanternsApp.frame_shapes({ scene: SceneCycle.scene_after(SceneCycle.first_scene, 1300), play: Playing })
	jet_shapes.len() == 25 and jet_shapes.all(|shape| frame.contains(shape))
}

## How high on the screen the top of the bird's drawing reaches in `scene`, the
## highest its pose reaches, or `Unseen` when the bird is behind the camera.
bird_drawing_top : SceneCycle.Scene -> [Top(F64), Unseen]
bird_drawing_top = |{ flight, steps_into_leg, steps }| {
	camera = SceneCycle.camera_at(steps)
	bird = flight.bird_instant_at(SceneCycle.flight_stage(steps_into_leg))
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
	frame = LanternsApp.frame_shapes({ scene: SceneCycle.scene_after(SceneCycle.first_scene, 700), play: Playing })
	plane.len() > 20 and plane.all(|shape| frame.contains(shape))
}
expect {
	right = Input.none.with_key_pressed(KeyRight)
	before = { scene: SceneCycle.scene_after(SceneCycle.first_scene, 380), play: Playing }
	skipped = model_at_next_step(before, right)
	BannerPlane.flight_at(before.scene.steps) == Coming and BannerPlane.flight_at(skipped.scene.steps) != Coming
}

# A frame draws the backdrop, the lamps, their pools and the bird.
expect LanternsApp.frame_shapes({ scene: { flight: BirdFlight.first, steps_into_leg: 40, steps: 40 }, play: Playing }).len() > 50
