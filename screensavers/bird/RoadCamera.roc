## RoadCamera is the camera that follows the bird down the road: where it
## stands, and how a point by the road lands on the screen through it. The
## camera looks level down the road, so a point's place on the screen is its
## step to the right and up from the camera, each over how far ahead it is,
## times the focal length.
##
## The horizon sits below the middle of the screen, as if the lens were shifted
## down, so the treetops the bird flies between stay in view while the camera
## stands above the road.
import lib.Pixels
import lib.Point

RoadCamera :: { along : F64, across : F64, height : F64 }.{

	## The camera at `along` and `across` in metres, `camera_height` up.
	at : { along : F64, across : F64 } -> RoadCamera
	at = |{ along, across }| RoadCamera.({ along, across, height: camera_height })

	## How far along the road the camera stands.
	along : RoadCamera -> F64
	along = |RoadCamera.(camera)| camera.along

	## How far ahead of the camera a place `along` the road is.
	forward_of : RoadCamera, F64 -> F64
	forward_of = |RoadCamera.(camera), place_along| place_along - camera.along

	## Where a point by the road lands on the screen, or `BehindCamera` for one
	## nearer than `near_plane`.
	project : RoadCamera, { along : F64, across : F64, lift : F64 } -> Try(Point, [BehindCamera])
	project = |RoadCamera.(camera), { along: point_along, across: point_across, lift }| {
		forward = point_along - camera.along
		if forward < near_plane {
			Err(BehindCamera)
		} else {
			Ok(
				Point.at(
					center_x + focal_length * (point_across - camera.across) / forward,
					horizon_y - focal_length * (lift - camera.height) / forward,
				),
			)
		}
	}

	## How tall something `height` metres tall looks `forward` metres ahead.
	size_on_screen : { height : F64, forward : F64 } -> Pixels
	size_on_screen = |{ height, forward }| Pixels.of(focal_length * height / forward)

	## The screen's size in pixels.
	screen_width : F64
	screen_width = 960.0

	screen_height : F64
	screen_height = 600.0

	## Where the horizon crosses the screen.
	horizon_y : F64
	horizon_y = 360.0

	## The nearest a point can be and still be drawn.
	near_plane : F64
	near_plane = 1.0
}

## How far up the camera stands, chosen by eye: high enough to see the road
## between the trees, and low enough that the treetops are against the sky.
camera_height : F64
camera_height = 5.0

## The lens's focal length in pixels, chosen by eye.
focal_length : F64
focal_length = 600.0

center_x : F64
center_x = RoadCamera.screen_width / 2.0

sample_camera : RoadCamera
sample_camera = RoadCamera.at({ along: 100.0, across: 0.0 })

# A point at the camera's height straight ahead is on the horizon in the
# middle, one to the right lands right of the middle, and one below the camera
# lands below the horizon.
expect sample_camera.project({ along: 130.0, across: 0.0, lift: 5.0 }) == Ok(Point.at(480.0, 360.0))
expect sample_camera.project({ along: 130.0, across: 3.0, lift: 5.0 }) == Ok(Point.at(540.0, 360.0))
expect sample_camera.project({ along: 130.0, across: 0.0, lift: 2.0 }) == Ok(Point.at(480.0, 420.0))

# A point at the near plane is drawn, and one just short of it is not.
expect sample_camera.project({ along: 101.0, across: 0.0, lift: 5.0 }).is_ok()
expect sample_camera.project({ along: 100.5, across: 0.0, lift: 5.0 }) == Err(BehindCamera)
