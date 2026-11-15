## Sunrise is the light of one cycle of the screensaver, given how far into the
## day it is: 0 as the cycle starts, at dawn, with the sun still behind the far
## range in the notch of its ridge, and 1 at full morning, with the sun well
## up. The sun climbs a straight path out of the notch, and the sky, the land
## and the road brighten with it at an even pace, so the scene grows lighter
## all the way to the cycle's end.
import Easing
import lib.Fraction
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.ColorShade

Sunrise :: [].{

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

	## The light when it is `day` of the way from dawn to full morning. The
	## colours move at an even pace, not eased, so the scene never seems to
	## stop brightening; the sun climbs at an even pace too. Even at dawn the
	## grass is a fresh green, dusky enough for the lamps' pools to show on it.
	light_at : Fraction -> Sunrise.Light
	light_at = |day| {
		between = |{ dawn, morning }| ColorShade.color_between({ from: RgbColor.of(dawn), to: RgbColor.of(morning), fraction: day })
		{
			sky_top: between({ dawn: 0x2E4580, morning: 0x6FA0E0 }),
			sky_horizon: between({ dawn: 0xF49A5C, morning: 0xFFE6BC }),
			far_range: between({ dawn: 0x5F5880, morning: 0x9C98BC }),
			hills: between({ dawn: 0x4C5E3C, morning: 0x7E9C66 }),
			grass_far: between({ dawn: 0x5E8048, morning: 0x8DB866 }),
			grass_near: between({ dawn: 0x40663A, morning: 0x669A4A }),
			road: between({ dawn: 0x524E5A, morning: 0x807C88 }),
			sun_center: sun_center_at(day),
			sun_inner: between({ dawn: 0xFFD08A, morning: 0xFFF8E0 }),
			sun_outer: between({ dawn: 0xFF7E48, morning: 0xFFD090 }),
			sun_glow: between({ dawn: 0xFFA868, morning: 0xFFE8B0 }),
			sun_glow_alpha: Easing.lerp({ from: 0.5, to: 0.45, fraction: day }),
		}
	}

	## The far range's outline, left to right, closed along the horizon so it
	## can be filled. The sun rises out of the notch at its lowest point.
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

## Where the sun starts the cycle: just under the notch at (560, 232), deep
## enough that it stays wholly hidden for the cycle's first three crossings
## (198 of its 1350 steps) and first peeks over the ridge at the next step,
## chosen by sweeping the path step by step. It lies on the straight line to
## `sun_end`, so the rise keeps its path however long the cycle.
sun_start : { x : F64, y : F64 }
sun_start = { x: 553.0, y: 301.0 }

## Where it ends, high in the sky left of the notch, chosen by eye.
sun_end : { x : F64, y : F64 }
sun_end = { x: 480.0, y: 60.0 }

sun_center_at : Fraction -> Point
sun_center_at = |day|
	Point.at(
		Easing.lerp({ from: sun_start.x, to: sun_end.x, fraction: day }),
		Easing.lerp({ from: sun_start.y, to: sun_end.y, fraction: day }),
	)

## How high the ridge is at `x`, read off the straight edge between the two
## ridge points either side of it.
ridge_y_at : F64 -> F64
ridge_y_at = |x| {
	var $y = horizon_below
	for k in 0..<(far_ridge.len() - 1) {
		left = far_ridge.get(k) ?? crash "Sunrise.ridge_y_at: a ridge point inside the list"
		right = far_ridge.get(k + 1) ?? crash "Sunrise.ridge_y_at: a ridge point inside the list"
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

# The sun starts wholly behind the ridge and stays there through the first
# three crossings of the cycle's twenty and a perch (198 of its 1350 steps),
# peeks over it at the next step, climbs clear of it at step 765, about 0.57
# of the way, and is clear at the end. Each boundary is pinned at the step
# either side of it, as `LanternsApp.day_at` reads a step.
expect sun_against_ridge(sun_center_at(Fraction.zero)) == Hidden
expect sun_against_ridge(sun_center_at(Fraction.of(198.0 / 1350.0))) == Hidden
expect sun_against_ridge(sun_center_at(Fraction.of(199.0 / 1350.0))) == Touching
expect sun_against_ridge(sun_center_at(Fraction.of(764.0 / 1350.0))) == Touching
expect sun_against_ridge(sun_center_at(Fraction.of(765.0 / 1350.0))) == Clear
expect sun_against_ridge(sun_center_at(Fraction.whole)) == Clear

# The ridge is read between its points, and is the points themselves at them.
expect ridge_y_at(560.0) == 232.0 and ridge_y_at(480.0) == 191.0

# The light runs from dawn's colours to the morning's, the sky brighter at
# each step along the way.
expect Sunrise.light_at(Fraction.zero).sky_top == RgbColor.of(0x2E4580)
expect Sunrise.light_at(Fraction.whole).sky_top == RgbColor.of(0x6FA0E0)
expect {
	dawn = Sunrise.light_at(Fraction.zero).sky_top
	middle = Sunrise.light_at(Fraction.of(0.5)).sky_top
	morning = Sunrise.light_at(Fraction.whole).sky_top
	dawn.blue() < middle.blue() and middle.blue() < morning.blue()
}
