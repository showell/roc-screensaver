## SceneCycle is where the lanterns' cycle has got to, and how it moves on a
## step at a time. The scene is one flight, how many steps into it the
## screensaver is, and how many steps into the cycle, so it stays the same size
## however long it plays. Each leg of the bird's journey is a perch, then a
## flight; when a leg ends, the next flight starts from the lamp the bird
## landed on. The cycle is twenty legs and a closing perch, and then it starts
## again from its first scene, so it repeats exactly.
##
## The camera moves down the road at one constant speed, the bird's own pace
## over a leg, so the bird draws ahead of it through each flight and it
## catches up through each perch. The day brightens from dawn at an even pace
## to the cycle's last step.
import Bird
import BirdFlight
import RoadCamera
import RoadLamps
import lib.Fraction

SceneCycle :: [].{

	## Where the cycle has got to: everything a frame is drawn from.
	Scene : { flight : BirdFlight, steps_into_leg : U64, steps : U64 }

	## How many steps a leg takes: the perch, then the flight.
	leg_steps : U64
	leg_steps = perch_steps + BirdFlight.frame_count

	## How many steps the whole cycle takes: the crossings, then the closing perch.
	cycle_steps : U64
	cycle_steps = rising_crossings * SceneCycle.leg_steps + closing_perch_steps

	## The scene the cycle starts from, and starts again from each time round.
	first_scene : SceneCycle.Scene
	first_scene = { flight: BirdFlight.first, steps_into_leg: 0, steps: 0 }

	## How far into the day it is `steps` into the cycle: 0 at dawn as the cycle
	## starts, then a little more at every step to the last, so the scene never
	## stops brightening before it starts again.
	day_at : U64 -> Fraction
	day_at = |steps| Fraction.clamp(steps.to_f64() / SceneCycle.cycle_steps.to_f64())

	## The scene one step on: a step into the leg, the next leg from the lamp the
	## bird landed on, or the cycle's first scene again after its last step.
	scene_at_next_step : SceneCycle.Scene -> SceneCycle.Scene
	scene_at_next_step = |scene| {
		steps_into_leg = scene.steps_into_leg + 1
		steps = scene.steps + 1
		if steps >= SceneCycle.cycle_steps {
			SceneCycle.first_scene
		} else if steps_into_leg >= SceneCycle.leg_steps {
			{ flight: scene.flight.next(), steps_into_leg: 0, steps }
		} else {
			{ ..scene, steps_into_leg, steps }
		}
	}

	## The scene `count` steps on, played one at a time.
	scene_after : SceneCycle.Scene, U64 -> SceneCycle.Scene
	scene_after = |scene, count| {
		var $scene = scene
		for _k in 0..<count {
			$scene = SceneCycle.scene_at_next_step($scene)
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
}

## How many steps the bird sits on its lamp before each flight, chosen by eye.
perch_steps : U64
perch_steps = 30

## The cycle runs over this many whole crossings, a leg each: about 45 s, short
## enough to watch it come round, long enough that the rise is not rushed.
rising_crossings : U64
rising_crossings = 20

## How many steps the cycle takes past its crossings: one perch, so the bird
## sits on its lamp at the end and the scene starts again just as it would
## take off.
closing_perch_steps : U64
closing_perch_steps = perch_steps

## How far the camera moves down the road each step: one lamp spacing a leg,
## which is the bird's pace, since every flight is one place on.
camera_speed : F64
camera_speed = RoadLamps.lamp_spacing / SceneCycle.leg_steps.to_f64()

## How far behind the even place of the bird's lamp the camera is as each leg
## starts, just as the bird lands, chosen by eye. Through the perch the camera
## closes by a perch's worth of its speed (about 14 m), so the bird takes off
## about 20 m ahead, as near as is comfortable to look at; a lamp's nudge moves
## either by up to 6 m.
follow_distance : F64
follow_distance = 34.0

# A leg is a perch, then a flight, and the next leg starts from where the
# bird landed.
expect SceneCycle.flight_stage(0) == Waiting and SceneCycle.flight_stage(perch_steps - 1) == Waiting
expect SceneCycle.flight_stage(perch_steps) == Playing(0)
expect SceneCycle.flight_stage(SceneCycle.leg_steps - 1) == Playing(BirdFlight.frame_count - 1)
expect {
	last_of_leg = { flight: BirdFlight.first, steps_into_leg: SceneCycle.leg_steps - 1, steps: 99 }
	after = SceneCycle.scene_at_next_step(last_of_leg)
	after.steps_into_leg == 0 and after.flight == BirdFlight.first.next() and after.steps == 100
}

# Through the whole cycle the bird stays between 12 m and 45 m ahead of the
# camera, and all of its drawing, the widest and tallest its pose reaches either
# way, stays on the screen; and the cycle ends on the first scene again.
expect {
	var $scene = SceneCycle.first_scene
	var $nearest = 1000.0.F64
	var $farthest = 0.0.F64
	var $off_screen = 0
	for _step in 0..<SceneCycle.cycle_steps {
		{ flight, steps_into_leg, steps } = $scene
		camera = SceneCycle.camera_at(steps)
		bird = flight.bird_instant_at(SceneCycle.flight_stage(steps_into_leg))
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
		$scene = SceneCycle.scene_at_next_step($scene)
	}
	$nearest >= 12.0 and $farthest <= 45.0 and $off_screen == 0 and $scene == SceneCycle.first_scene
}

# The camera keeps one speed, and is the same at the start of each cycle.
expect (SceneCycle.camera_at(SceneCycle.leg_steps).along() - SceneCycle.camera_at(0).along() - RoadLamps.lamp_spacing).abs() < 1.0e-9
expect (SceneCycle.camera_at(2 * SceneCycle.leg_steps).along() - SceneCycle.camera_at(SceneCycle.leg_steps).along() - RoadLamps.lamp_spacing).abs() < 1.0e-9
expect SceneCycle.camera_at(0).along() == RoadLamps.even_along(0) - follow_distance

# The cycle is twenty legs and a closing perch, and it starts again from the
# first scene on its last step and not a step before.
expect SceneCycle.cycle_steps == 20 * 66 + 30
expect {
	last = { flight: BirdFlight.first, steps_into_leg: 29, steps: SceneCycle.cycle_steps - 1 }
	SceneCycle.scene_at_next_step(last) == SceneCycle.first_scene
}
expect {
	before_last = { flight: BirdFlight.first, steps_into_leg: 28, steps: SceneCycle.cycle_steps - 2 }
	after = SceneCycle.scene_at_next_step(before_last)
	after.steps == SceneCycle.cycle_steps - 1 and after.steps_into_leg == 29
}

# The day runs from 0 at dawn and grows at every step, up to the last.
expect SceneCycle.day_at(0) == Fraction.zero
# Sunrise's expects pin the sun's first peek and its clearing at steps of a
# 1350-step cycle, which is the day this one gives at those steps.
expect SceneCycle.day_at(199) == Fraction.of(199.0 / 1350.0) and SceneCycle.day_at(765) == Fraction.of(765.0 / 1350.0)
expect SceneCycle.day_at(SceneCycle.cycle_steps / 2) == Fraction.of(0.5)
expect SceneCycle.day_at(SceneCycle.cycle_steps - 2) < SceneCycle.day_at(SceneCycle.cycle_steps - 1) and SceneCycle.day_at(SceneCycle.cycle_steps - 1) != Fraction.whole
