## RoadsideShapes is what stands by the road, seen through the camera: each
## lamp and the bird, as a thing drawn by its distance from the camera, so a
## frame can paint the farthest first, and the pool of light each lamp throws
## on the ground under them.
import Bird
import BirdFlight
import LampShapes
import RoadCamera
import RoadLamps
import StillOnScreen
import lib.Brush
import lib.Fraction
import lib.Point
import lib.Shapes

RoadsideShapes :: [].{

	## One thing by the road, drawn by its distance from the camera.
	Drawn : { forward : F64, shapes : List(Shapes.Shape) }

	## A lamp on the screen, if it is in front of the camera.
	drawn_lamp : RoadCamera, { lamp : RoadLamps.RoadLamp, day : Fraction } -> Try(RoadsideShapes.Drawn, [BehindCamera])
	drawn_lamp = |camera, { lamp, day }| {
		foot = camera.project({ along: lamp.along, across: lamp.across, lift: 0.0 })?
		forward = camera.forward_of(lamp.along)
		height_on_screen = RoadCamera.size_on_screen({ height: lamp.lantern.height_metres(), forward })
		Ok({ forward, shapes: LampShapes.lamp_shapes({ foot, height_on_screen }, { lantern: lamp.lantern, day }) })
	}

	## The bird on the screen, if it is in front of the camera, as a list of none
	## or one.
	drawn_birds : RoadCamera, { bird : BirdFlight.BirdInstant, flight : BirdFlight } -> List(RoadsideShapes.Drawn)
	drawn_birds = |camera, { bird, flight }|
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

	## The pool of light a lamp throws on the ground: the circle round its foot,
	## seen through the camera, lit brightest at the foot and fading to nothing at
	## its edge, strongest at dawn and fainter as the day comes up. None for a pool any of
	## whose edge is behind the camera.
	light_pool_shapes : RoadCamera, { lamp : RoadLamps.RoadLamp, day : Fraction } -> List(Shapes.Shape)
	light_pool_shapes = |camera, { lamp, day }| {
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
			least_x = xs.fold(1.0e9, |least, x| least.min(x))
			most_x = xs.fold(-1.0e9, |most, x| most.max(x))
			least_y = ys.fold(1.0e9, |least, y| least.min(y))
			most_y = ys.fold(-1.0e9, |most, y| most.max(y))
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
}

## How far a lamp's pool of light spreads on the ground, in metres, chosen by
## eye.
pool_radius : F64
pool_radius = 3.2
