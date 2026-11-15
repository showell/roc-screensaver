## Sunset is the light of one cycle of the screensaver, given how near dusk it
## is: 0 as the cycle starts, with the sun well up and the scene in an early,
## gentle dusk, and 1 once the sun has gone down behind the far range. The sun
## moves down a straight path as dusk nears, and the sky, the land and the road
## ease toward the colours of dusk with it, so the lamps read a little stronger
## as it goes.
import Easing
import lib.Fraction
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.ColorShade

Sunset :: [].{

	## The scene's colours and the sun's place at one moment of the cycle.
	Light : {
		sky_top : RgbColor,
		sky_horizon : RgbColor,
		far_range : RgbColor,
		hills : RgbColor,
		grass_far : RgbColor,
		grass_near : RgbColor,
		road : RgbColor,
		sun_center : Point,
		sun_inner : RgbColor,
		sun_outer : RgbColor,
		sun_glow : RgbColor,
		sun_glow_alpha : F64,
	}

	## The light when it is `dusk` of the way to the sun's set. The colours
	## ease in and out, so the scene changes slowest at the cycle's two ends;
	## the sun moves at an even pace, as a real one does.
	light_at : Fraction -> Sunset.Light
	light_at = |dusk| {
		eased = Easing.smoothstep(dusk)
		between = |{ early, late }| ColorShade.color_between({ from: RgbColor.of(early), to: RgbColor.of(late), fraction: eased })
		{
			sky_top: between({ early: 0x5B7FC4, late: 0x334C8A }),
			sky_horizon: between({ early: 0xFFCB8E, late: 0xF4A15F }),
			far_range: between({ early: 0x8A82A8, late: 0x665F84 }),
			hills: between({ early: 0x6B8058, late: 0x4F5F3E }),
			grass_far: between({ early: 0x5C7349, late: 0x3F5235 }),
			grass_near: between({ early: 0x354A2D, late: 0x22321E }),
			road: between({ early: 0x6F6B76, late: 0x54505B }),
			sun_center: sun_center_at(dusk),
			sun_inner: between({ early: 0xFFF0C4, late: 0xFFDA94 }),
			sun_outer: between({ early: 0xFFB874, late: 0xFF8A4E }),
			sun_glow: between({ early: 0xFFD490, late: 0xFFB070 }),
			sun_glow_alpha: Easing.lerp({ from: 0.55, to: 0.4, fraction: eased }),
		}
	}

	## The far range's outline, left to right, closed along the horizon so it
	## can be filled. The sun sets into the notch at its lowest point.
	far_range : List(Point)
	far_range = far_ridge.concat([Point.at(960.0, horizon_below), Point.at(0.0, horizon_below)])

	## How big the sun is.
	sun_radius : Pixels
	sun_radius = Pixels.of(sun_radius_f64)
}

## The far range's ridge line, left to right, chosen by eye.
far_ridge : List(Point)
far_ridge = [
	Point.at(0.0, 250.0),
	Point.at(120.0, 200.0),
	Point.at(250.0, 238.0),
	Point.at(400.0, 150.0),
	Point.at(560.0, 232.0),
	Point.at(690.0, 188.0),
	Point.at(820.0, 258.0),
	Point.at(960.0, 205.0),
]

## Just under the horizon, so the range meets the grass with no gap. It is
## RoadCamera's horizon, which this module does not import, plus one.
horizon_below : F64
horizon_below = 381.0

sun_radius_f64 : F64
sun_radius_f64 = 38.0

## Where the sun starts the cycle, high in the sky left of the notch, chosen
## by eye.
sun_start : { x : F64, y : F64 }
sun_start = { x: 480.0, y: 60.0 }

## Where it ends: under the notch at (560, 232), just deep enough that its top
## is below the ridge everywhere, so it is wholly hidden as dusk reaches 1.
sun_end : { x : F64, y : F64 }
sun_end = { x: 560.0, y: 271.0 }

sun_center_at : Fraction -> Point
sun_center_at = |dusk|
	Point.at(
		Easing.lerp({ from: sun_start.x, to: sun_end.x, fraction: dusk }),
		Easing.lerp({ from: sun_start.y, to: sun_end.y, fraction: dusk }),
	)

## How high the ridge is at `x`, read off the straight edge between the two
## ridge points either side of it.
ridge_y_at : F64 -> F64
ridge_y_at = |x| {
	var $y = horizon_below
	for k in 0..<(far_ridge.len() - 1) {
		left = far_ridge.get(k) ?? crash "Sunset.ridge_y_at: a ridge point inside the list"
		right = far_ridge.get(k + 1) ?? crash "Sunset.ridge_y_at: a ridge point inside the list"
		x0 = left.x.to_f64()
		x1 = right.x.to_f64()
		if x >= x0 and x <= x1 {
			$y = left.y.to_f64() + (right.y.to_f64() - left.y.to_f64()) * (x - x0) / (x1 - x0)
		} else {
			{}
		}
	}
	$y
}

## Where the sun's disc stands against the ridge, read at 33 places across it:
## wholly above the ridge, partly behind it, or wholly behind it.
SunAgainstRidge : [Clear, Touching, Hidden]

sun_against_ridge : Point -> SunAgainstRidge
sun_against_ridge = |center| {
	cx = center.x.to_f64()
	cy = center.y.to_f64()
	var $above = 0
	var $behind = 0
	for k in 0..=32 {
		dx = sun_radius_f64 * (k.to_f64() / 16.0 - 1.0)
		half_height = (sun_radius_f64 * sun_radius_f64 - dx * dx).max(0.0).sqrt()
		ridge = ridge_y_at(cx + dx)
		if cy + half_height < ridge {
			$above = $above + 1
		} else {
			{}
		}
		if cy - half_height >= ridge {
			$behind = $behind + 1
		} else {
			{}
		}
	}
	if $above == 33 {
		Clear
	} else if $behind == 33 {
		Hidden
	} else {
		Touching
	}
}

# The sun starts clear of the ridge, is still showing just before dusk is
# whole, and is wholly behind the ridge once it is.
expect sun_against_ridge(sun_center_at(Fraction.zero)) == Clear
expect sun_against_ridge(sun_center_at(Fraction.of(0.5))) == Clear
expect sun_against_ridge(sun_center_at(Fraction.of(0.75))) == Touching
expect sun_against_ridge(sun_center_at(Fraction.of(0.985))) == Touching
expect sun_against_ridge(sun_center_at(Fraction.whole)) == Hidden

# The ridge is read between its points, and is the points themselves at them.
expect ridge_y_at(560.0) == 232.0 and ridge_y_at(480.0) == 191.0

# The light runs from the early colours to the late ones.
expect Sunset.light_at(Fraction.zero).sky_top == RgbColor.of(0x5B7FC4)
expect Sunset.light_at(Fraction.whole).sky_top == RgbColor.of(0x334C8A)
