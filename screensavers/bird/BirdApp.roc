## BirdApp is the screensaver as a value a runner can play: the Roc bird
## flying from tree to tree down a road that never ends, with the camera
## following it. It needs no input.
##
## The model is one flight and how many steps into it the screensaver is, so it
## stays the same size however long it plays. Each leg of the bird's journey is
## a perch, then a flight; when a leg ends, the next flight starts from the tree
## the bird landed on. The camera moves down the road at a steady pace through
## each leg, so it closes on the perched bird and the bird then flies off ahead
## of it.
import Bird
import BirdFlight
import ConiferShapes
import RoadCamera
import RoadTrees
import StillOnScreen
import lib.Brush
import lib.CanvasApp
import lib.Input
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes

BirdApp :: [].{
	Model : { flight : BirdFlight, steps_into_leg : U64 }

	canvas_app : CanvasApp.CanvasApp(BirdApp.Model)
	canvas_app = {
		size: { width: RoadCamera.screen_width, height: RoadCamera.screen_height },
		# Safari's motion is written per step at thirty steps a second, and the
		# flight is Safari's, so it plays at the same rate.
		frames_a_second: 30,
		init: { flight: BirdFlight.first, steps_into_leg: 0 },
		model_at_next_step: CanvasApp.untimed_model_at_next_step(model_at_next_step),
		frame_shapes,
		sounds: |_model| 0,
		tones: [],
		title: "Bird",
	}
}

## How many steps the bird sits on its tree before each flight, chosen by eye.
perch_steps : U64
perch_steps = 30

## How many steps a leg takes: the perch, then the flight.
leg_steps : U64
leg_steps = perch_steps + BirdFlight.frame_count

## How far behind the bird's tree the camera is as a leg starts, chosen by eye.
follow_distance : F64
follow_distance = 30.0

## How far ahead of the camera a tree is still drawn.
view_depth : F64
view_depth = 400.0

model_at_next_step : BirdApp.Model, Input.Snapshot -> BirdApp.Model
model_at_next_step = |model, _input| {
	steps_into_leg = model.steps_into_leg + 1
	if steps_into_leg >= leg_steps {
		{ flight: model.flight.next(), steps_into_leg: 0 }
	} else {
		{ ..model, steps_into_leg }
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

## The camera `steps_into_leg` steps into the leg of `flight`: from
## `follow_distance` behind the tree the bird leaves to as far behind the tree
## it lands on, at a steady pace.
camera_at : BirdFlight, U64 -> RoadCamera
camera_at = |flight, steps_into_leg| {
	{ from, to } = flight.trees()
	share = steps_into_leg.to_f64() / leg_steps.to_f64()
	along = from.along + (to.along - from.along) * share - follow_distance
	RoadCamera.at({ along, across: 0.0 })
}

## One thing by the road, drawn by its distance from the camera.
Drawn : { forward : F64, shapes : List(Shapes.Shape) }

frame_shapes : BirdApp.Model -> List(Shapes.Shape)
frame_shapes = |{ flight, steps_into_leg }| {
	camera = camera_at(flight, steps_into_leg)
	trees = RoadTrees.trees_between({
		nearest: camera.along() + RoadCamera.near_plane,
		farthest: camera.along() + view_depth,
	})
	drawn_trees = trees.keep_oks(|tree| drawn_tree(camera, tree))
	bird = flight.bird_instant_at(flight_stage(steps_into_leg))
	drawn_bird = drawn_bird_of(camera, { bird, heading: flight.heading() })
	# Farthest first, so a nearer thing paints over a farther one.
	by_distance = drawn_trees.concat(drawn_bird).sort_with(
		|a, b|
			if a.forward > b.forward {
				Before
			} else if a.forward < b.forward {
				After
			} else {
				Same
			},
	)
	backdrop_shapes(camera).concat(by_distance.join_map(|drawn| drawn.shapes))
}

## A tree on the screen, if it is in front of the camera.
drawn_tree : RoadCamera, RoadTrees.RoadTree -> Try(Drawn, [BehindCamera])
drawn_tree = |camera, tree| {
	foot = camera.project({ along: tree.along, across: tree.across, lift: 0.0 })?
	forward = camera.forward_of(tree.along)
	height_on_screen = RoadCamera.size_on_screen({ height: tree.conifer.height_metres(), forward })
	Ok({
		forward,
		shapes: ConiferShapes.tree_shapes({ foot, height_on_screen }, { conifer: tree.conifer, forward }),
	})
}

## The bird on the screen, if it is in front of the camera, as a list of none
## or one.
drawn_bird_of : RoadCamera, { bird : BirdFlight.BirdInstant, heading : BirdFlight.Heading } -> List(Drawn)
drawn_bird_of = |camera, { bird, heading }|
	match camera.project(bird.location) {
		Err(BehindCamera) => []
		Ok(foot) => {
			forward = camera.forward_of(bird.location.along)
			anchor = {
				foot,
				flip: Bird.pose_flip(bird.pose, heading),
				height_on_screen: RoadCamera.size_on_screen({ height: Bird.height_metres, forward }),
			}
			# A tree's own foliage would hide a bird perched on its tip, so the
			# bird is drawn just nearer than the tree it stands on.
			[{ forward: forward - 0.01, shapes: StillOnScreen.still_shapes(anchor, Bird.pose_still(bird.pose)) }]
		}
	}

sky_color : RgbColor
sky_color = RgbColor.of(0x8ECAE6)

grass_color : RgbColor
grass_color = RgbColor.of(0x4A8F43)

road_color : RgbColor
road_color = RgbColor.of(0x5A5D61)

line_color : RgbColor
line_color = RgbColor.of(0xEDE6C8)

road_half_width : F64
road_half_width = 2.0

## The sky, the grass, the road to the horizon, and the dashes down its middle.
backdrop_shapes : RoadCamera -> List(Shapes.Shape)
backdrop_shapes = |camera| {
	sky = Shapes.rectangle({
		top_left: Point.at(0.0, 0.0),
		width: Pixels.of(RoadCamera.screen_width),
		height: Pixels.of(RoadCamera.horizon_y),
		fill: Brush.flat(sky_color),
	})
	grass = Shapes.rectangle({
		top_left: Point.at(0.0, RoadCamera.horizon_y),
		width: Pixels.of(RoadCamera.screen_width),
		height: Pixels.of(RoadCamera.screen_height - RoadCamera.horizon_y),
		fill: Brush.flat(grass_color),
	})
	near = camera.along() + 1.5
	far = camera.along() + 5000.0
	road = ground_quad(camera, { near, far, left: 0.0 - road_half_width, right: road_half_width }, road_color)
	[sky, grass].concat(road).concat(dash_shapes(camera))
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
	first_dash = (camera.along() / dash_spacing).floor_to_i64_try() ?? crash "BirdApp.dash_shapes: a road longer than an I64 of dashes"
	count = (dash_reach / dash_spacing).floor_to_u64_try() ?? crash "BirdApp.dash_shapes: a reach that is no count of dashes"
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
	last_of_leg = { flight: BirdFlight.first, steps_into_leg: leg_steps - 1 }
	after = model_at_next_step(last_of_leg, Input.none)
	after.steps_into_leg == 0 and after.flight == BirdFlight.first.next()
}

# The camera ends a leg where it starts the next, so it never jumps.
expect {
	flight = BirdFlight.first
	camera_at(flight, leg_steps).along() == camera_at(flight.next(), 0).along()
}

# A frame draws the backdrop, the trees and the bird.
expect frame_shapes({ flight: BirdFlight.first, steps_into_leg: 40 }).len() > 50
