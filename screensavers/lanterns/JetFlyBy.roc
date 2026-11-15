## JetFlyBy is the fly-by that closes each cycle, after the banner plane has
## gone: five small jets in a V, deep blue with yellow trim, come over the
## camera from behind it and streak away up the sky to the right, shrinking
## fast as the distance grows, and fade out before the cycle starts again.
## Where they are depends on the cycle's step alone, so a restart, the rewind
## and a skip move them with everything else.
##
## The jets fly a straight, climbing path laid out from where the camera
## stands, and each corner of each jet is seen through RoadCamera's own
## projection, so they shrink and foreshorten as everything by the road does.
## The camera's own creep down the road is not in the path: beside the jets'
## speed it is too small to see. Each jet is a flat outline in the plane of its
## flight, seen from below, with a pale trail of smoke behind it.
import RoadCamera
import lib.Brush
import lib.Point
import lib.RgbColor
import lib.Shapes

JetFlyBy :: [].{

	## One jet as the scene draws it: how far ahead of the camera it is, by
	## which the scene sorts it among the lamps and the bird, and its shapes.
	DrawnJet : { forward : F64, shapes : List(Shapes.Shape) }

	## The jets `steps` into the cycle, one for each in the formation, or none
	## before the pass starts and after it ends.
	jets_at : U64 -> List(JetFlyBy.DrawnJet)
	jets_at = |steps|
		match flown_at(steps) {
			Flown(flown) => formation_slots.map(|slot| drawn_jet(flown, slot))
			Coming => []
			Gone => []
		}

	## The step the pass starts at, and the step it is gone by.
	enters_step : U64
	enters_step = 1276

	ends_step : U64
	ends_step = 1340
}

## A place in the camera's own frame, in metres: ahead of it, to its right, and
## up from the ground.
Place : {
	along : F64,
	across : F64,
	lift : F64,
}

## How far along its path the lead jet has flown `steps` into the cycle, and how
## solid the jets are drawn as they fade at the end of the pass.
Flight : [
	Coming,
	Flown({ metres : F64, alpha : F64 }),
	Gone,
]

flown_at : U64 -> Flight
flown_at = |steps|
	if steps < JetFlyBy.enters_step {
		Coming
	} else if steps >= JetFlyBy.ends_step {
		Gone
	} else {
		into = (steps - JetFlyBy.enters_step).to_f64()
		left = (JetFlyBy.ends_step - steps).to_f64()
		Flown({ metres: speed * into, alpha: (left / fade_steps.to_f64()).min(1.0) })
	}

## How far the jets fly each step, in metres: 300 m a second at thirty steps a
## second, fast enough that they shrink to specks within the pass.
speed : F64
speed = 10.0

## Over how many of the pass's last steps the jets fade out.
fade_steps : U64
fade_steps = 14

## The camera the path is laid out from: the scene's lens, standing at the
## origin of the path's frame.
view_camera : RoadCamera
view_camera = RoadCamera.at({ along: 0.0, across: 0.0 })

## Where the lead jet is as the pass starts: above and a little ahead of the
## camera, so it comes in over the top edge of the screen.
start_place : Place
start_place = {
	along: 55.0,
	across: -2.0,
	lift: 49.0,
}

## Which way the jets fly, as a step ahead, to the right and up for each metre
## ahead. A straight path ahead and up recedes toward one point in the sky,
## `RoadCamera`'s focal length times each over the camera's centre and horizon;
## these put it at about (630, 115), right of the sun and well above the ridge.
heading_step : Place
heading_step = {
	along: 1.0,
	across: 0.3,
	lift: 0.53,
}

## The path's heading as a unit vector.
heading : Place
heading = unit(heading_step)

## The two directions the formation and each jet's outline are laid out along:
## the heading made level, and level to the jets' right. A jet drawn in the
## plane of its climb would be seen nearly edge on, since the camera looks up
## at it at about the climb's own angle; drawn level, its belly faces the
## camera and its swept wings read.
level_heading : Place
level_heading = unit({ ..heading_step, lift: 0.0 })

right_hand : Place
right_hand = unit({
	along: 0.0 - heading_step.across,
	across: heading_step.along,
	lift: 0.0,
})

unit : Place -> Place
unit = |place| {
	length = length_of(place)
	{
		along: place.along / length,
		across: place.across / length,
		lift: place.lift / length,
	}
}

length_of : Place -> F64
length_of = |{ along, across, lift }| (along * along + across * across + lift * lift).sqrt()

## The place `ahead` metres along the level heading and `out` metres to the
## right of `place`.
offset_place : Place, { ahead : F64, out : F64 } -> Place
offset_place = |place, { ahead, out }| {
	along: place.along + ahead * level_heading.along + out * right_hand.along,
	across: place.across + ahead * level_heading.across + out * right_hand.across,
	lift: place.lift,
}

## The lead jet's place `metres` along its path.
lead_place : F64 -> Place
lead_place = |metres| {
	along: start_place.along + metres * heading.along,
	across: start_place.across + metres * heading.across,
	lift: start_place.lift + metres * heading.lift,
}

## Each jet's place in the V, behind the lead and out to its side, in metres.
formation_slots : List({ ahead : F64, out : F64 })
formation_slots = [
	{ ahead: 0.0, out: 0.0 },
	{ ahead: -13.0, out: -12.0 },
	{ ahead: -13.0, out: 12.0 },
	{ ahead: -26.0, out: -24.0 },
	{ ahead: -26.0, out: 24.0 },
]

## The jet's outline from below, nose first and round its right side, as
## metres ahead of its middle and out to its right: a swept wing, then the
## tailplane, about 18 m long and 12 m across.
outline_offsets : List((F64, F64))
outline_offsets = [
	(8.6, 0.0),
	(6.4, 0.6),
	(3.0, 1.0),
	(-3.0, 5.8),
	(-4.6, 5.8),
	(-4.0, 1.3),
	(-5.8, 1.3),
	(-8.0, 3.4),
	(-9.2, 3.4),
	(-8.8, 0.7),
	(-9.4, 0.0),
	(-8.8, -0.7),
	(-9.2, -3.4),
	(-8.0, -3.4),
	(-5.8, -1.3),
	(-4.0, -1.3),
	(-4.6, -5.8),
	(-3.0, -5.8),
	(3.0, -1.0),
	(6.4, -0.6),
]

## The yellow trim: a stripe down the middle and a band along each wing's
## leading edge.
trim_offsets : List(List((F64, F64)))
trim_offsets = [
	[
		(7.2, 0.3),
		(-8.6, 0.3),
		(-8.6, -0.3),
		(7.2, -0.3),
	],
	[
		(3.0, 1.0),
		(-3.0, 5.8),
		(-3.7, 5.8),
		(2.0, 1.0),
	],
	[
		(3.0, -1.0),
		(-3.0, -5.8),
		(-3.7, -5.8),
		(2.0, -1.0),
	],
]

## The trail of smoke behind a jet that has flown `metres`: it starts as the
## pass does, over the camera, and grows to its full length, so it never
## reaches back behind the camera.
trail_offsets : F64 -> List((F64, F64))
trail_offsets = |metres| {
	length = (metres / 2.0).min(trail_length)
	[
		(-9.4, 0.6),
		(-9.4 - length, 0.0),
		(-9.4, -0.6),
	]
}

trail_length : F64
trail_length = 40.0

body_color : RgbColor
body_color = RgbColor.of(0x10307A)

trim_color : RgbColor
trim_color = RgbColor.of(0xF2C230)

trail_color : RgbColor
trail_color = RgbColor.of(0xF4F4F8)

## How solid the trail is, beside the jets' own fade.
trail_alpha : F64
trail_alpha = 0.45

## One jet in its slot of the V, `metres` along the path, its middle the
## lead's moved by the slot, and `alpha` as solid as the fade leaves it.
drawn_jet : { metres : F64, alpha : F64 }, { ahead : F64, out : F64 } -> JetFlyBy.DrawnJet
drawn_jet = |{ metres, alpha }, slot| {
	middle = offset_place(lead_place(metres), slot)
	part = |offsets, fill| jet_part({ middle, offsets, fill })
	fill_of = |color, strength|
		if strength >= 1.0 {
			Brush.flat(color)
		} else {
			Flat(Brush.with_alpha(color, strength))
		}
	trail = part(trail_offsets(metres), Flat(Brush.with_alpha(trail_color, trail_alpha * alpha)))
	body = part(outline_offsets, fill_of(body_color, alpha))
	trims = trim_offsets.map(|offsets| part(offsets, fill_of(trim_color, alpha)))
	{ forward: view_camera.forward_of(middle.along), shapes: [trail, body].concat(trims) }
}

## The region round `offsets` from a jet's middle, each seen through the
## camera. The path keeps every corner in front of the camera through the pass.
jet_part : {
	middle : Place,
	offsets : List((F64, F64)),
	fill : Brush.Fill,
} -> Shapes.Shape
jet_part = |{ middle, offsets, fill }| {
	corners = offsets.map(
		|(ahead, out)|
			match view_camera.project(offset_place(middle, { ahead, out })) {
				Ok(point) => point
				Err(BehindCamera) => crash "JetFlyBy.jet_part: the path keeps every jet in front of the camera"
			},
	)
	Shapes.region_from_corners(corners, fill)
}

# The pass draws nothing a step before it starts, five jets at its first step
# and its last, and nothing from the step it ends to the cycle's last step, so
# it is over before the rewind at step 1350.
expect JetFlyBy.jets_at(JetFlyBy.enters_step - 1) == []
expect JetFlyBy.jets_at(JetFlyBy.enters_step).len() == 5
expect JetFlyBy.jets_at(JetFlyBy.ends_step - 1).len() == 5
expect JetFlyBy.jets_at(JetFlyBy.ends_step) == [] and JetFlyBy.jets_at(1349) == []
expect JetFlyBy.enters_step == 1276 and JetFlyBy.ends_step == 1340 and JetFlyBy.ends_step < 1350

# The jets are solid until the fade, then fainter at each step to the last.
expect flown_at(JetFlyBy.ends_step - fade_steps - 1) == Flown({ metres: speed * 49.0, alpha: 1.0 })
expect
	match (flown_at(JetFlyBy.ends_step - 2), flown_at(JetFlyBy.ends_step - 1)) {
		(Flown(before), Flown(last)) => before.alpha > last.alpha and last.alpha > 0.0
		_ => Bool.False
	}

# The path's heading climbs; the two directions the outline is laid out along
# are level, unit length, and at right angles, the right hand to the right.
expect [heading, level_heading, right_hand].all(|direction| (length_of(direction) - 1.0).abs() < tolerance)
expect heading.lift > 0.0 and level_heading.lift == 0.0 and right_hand.lift == 0.0
expect right_hand.across > 0.0
expect {
	dot = level_heading.along * right_hand.along + level_heading.across * right_hand.across
	dot.abs() < tolerance
}

tolerance : F64
tolerance = 1.0e-12

# Through the whole pass, every jet in the formation looks smaller at each
# step than at the step before, measured across its outline's widest and
# tallest reach on the screen.
expect {
	var $shrinking = 0
	var $growing = 0
	var $sizes_before = []
	for steps in JetFlyBy.enters_step..<JetFlyBy.ends_step {
		sizes = JetFlyBy.jets_at(steps).map(
			|jet| {
				body = jet.shapes.get(1) ?? crash "every jet has its outline second"
				corners = Shapes.region_corners(body) ?? crash "a jet's outline has corners"
				xs = corners.map(|p| p.x.to_f64())
				ys = corners.map(|p| p.y.to_f64())
				width = xs.fold(-1.0e9, |a, x| a.max(x)) - xs.fold(1.0e9, |a, x| a.min(x))
				height = ys.fold(-1.0e9, |a, y| a.max(y)) - ys.fold(1.0e9, |a, y| a.min(y))
				(width * width + height * height).sqrt()
			},
		)
		for k in 0..<$sizes_before.len() {
			before = $sizes_before.get(k) ?? crash "the formation keeps its five jets"
			now = sizes.get(k) ?? crash "the formation keeps its five jets"
			if now < before {
				$shrinking = $shrinking + 1
			} else {
				$growing = $growing + 1
			}
		}
		$sizes_before = sizes
	}
	$shrinking == 5 * 63 and $growing == 0
}
