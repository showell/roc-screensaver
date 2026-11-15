## TidesApp is the tides screensaver as a value a runner can play: six bands
## of water, one behind another, from a pale one at the horizon to a deep one
## at the bottom of the screen, each with a top edge that is a slow sum of
## swells drifting left, the nearer bands the faster. Over them the sky goes
## through dawn, day, dusk and night; the sun rises out of the sea at dawn and
## sinks back into it at dusk, and the moon crosses the night.
##
## The model is how many steps into the cycle it is and whether it is playing,
## and every frame is drawn from that count alone. Each swell makes a whole
## number of turns a cycle, so the water, like the sky, is just as it began
## when the cycle starts again, and every run plays the same frames.
##
## Space pauses and resumes, and R starts again at dawn, read from each
## step's input so the page and a native window behave alike.
import Daylight
import lib.Brush
import lib.CanvasApp
import lib.ColorShade
import lib.Fraction
import lib.Input
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes

TidesApp :: [].{
	Model : { steps : U64, play : TidesApp.Play }

	## Whether the cycle moves on at each step, or holds still for the viewer.
	Play : [Playing, Paused]

	canvas_app : CanvasApp.CanvasApp(TidesApp.Model)
	canvas_app = {
		size: { width: screen_width, height: screen_height },
		frames_a_second: 30,
		init: first_model,
		model_at_next_step: CanvasApp.untimed_model_at_next_step(model_at_next_step),
		frame_shapes: TidesApp.frame_shapes,
		sounds: |_model| 0,
		tones: [],
		title: "Tides",
		controls: [
			{ keys: "Space", does: "pauses and resumes" },
			{ keys: "R", does: "restarts at dawn" },
		],
	}

	## The sky, the sun and the moon where they are up, then the bands of
	## water, farthest first, so a nearer band paints over the one behind it.
	frame_shapes : TidesApp.Model -> List(Shapes.Shape)
	frame_shapes = |{ steps, play: _ }| {
		day = day_at(steps)
		light = Daylight.light_at(day)
		sky = Shapes.rectangle({
			top_left: Point.at(0.0, 0.0),
			width: Pixels.of(screen_width),
			height: Pixels.of(sea_level + 40.0),
			fill: Brush.linear_gradient({
				stops: {
					start_color: Brush.opaque_rgba(light.sky_top),
					end_color: Brush.opaque_rgba(light.sky_horizon),
					start_offset: 0.0,
					end_offset: 1.0,
				},
				start_point: Point.at(0.0, 0.0),
				end_point: Point.at(0.0, sea_level),
			}),
		})
		last_band = (bands.len() - 1).to_f64()
		water = bands.map_with_index(
			|band, index| {
				color = ColorShade.color_between({ from: light.water_pale, to: light.water_deep, fraction: Fraction.of(index.to_f64() / last_band) })
				Polygon({ corners: band_corners(band, steps), fill: Brush.flat(color) })
			},
		)
		[sky].concat(sun_shapes(day)).concat(moon_shapes(day)).concat(water)
	}
}

screen_width : F64
screen_width = 960.0

screen_height : F64
screen_height = 600.0

## How many steps the whole cycle takes, dawn to dawn: two minutes at thirty
## steps a second.
cycle_steps : U64
cycle_steps = 3600

## The model the screensaver starts from, at dawn and playing, and the one R
## goes back to, so a restart plays at once even from a pause.
first_model : TidesApp.Model
first_model = { steps: 0, play: Playing }

## The model after one step, given the keys. Each control reads a key struck
## at this step, never one held, and R is read before Space, so a step that
## strikes both restarts.
model_at_next_step : TidesApp.Model, Input.Snapshot -> TidesApp.Model
model_at_next_step = |model, input|
	if input.key_pressed(KeyR) {
		first_model
	} else if input.key_pressed(KeySpace) {
		match model.play {
			Playing => { ..model, play: Paused }
			Paused => { ..model, play: Playing }
		}
	} else {
		match model.play {
			Playing => { ..model, steps: (model.steps + 1) % cycle_steps }
			Paused => model
		}
	}

## How far through the cycle `steps` is, from 0 at dawn to just under 1.
day_at : U64 -> Fraction
day_at = |steps| Fraction.clamp(steps.to_f64() / cycle_steps.to_f64())

## A sine wave across the water: its height either way, the distance from one
## crest to the next, how many whole turns it drifts left over one cycle, and
## where along its turn it starts.
Swell : { height : F64, wavelength : F64, turns : U64, phase : F64 }

## One band of water: the level its top edge rises and falls about, and the
## swells that move it.
Band : { level : F64, swells : List(Swell) }

## The y of the horizon, where the farthest band's top rests.
sea_level : F64
sea_level = 300.0

## The bands, farthest first, chosen by eye. A nearer band is lower, its swells
## taller, longer and faster, and its level leaves room for the band behind
## it to show at its crests' highest and its troughs' lowest.
bands : List(Band)
bands = [
	{ level: sea_level, swells: [{ height: 3.0, wavelength: 260.0, turns: 2, phase: 0.0 }, { height: 2.0, wavelength: 150.0, turns: 3, phase: 1.3 }] },
	{ level: 345.0, swells: [{ height: 5.0, wavelength: 320.0, turns: 3, phase: 0.7 }, { height: 3.0, wavelength: 180.0, turns: 5, phase: 2.1 }] },
	{ level: 395.0, swells: [{ height: 7.0, wavelength: 380.0, turns: 4, phase: 1.9 }, { height: 4.0, wavelength: 210.0, turns: 7, phase: 0.4 }] },
	{ level: 450.0, swells: [{ height: 9.0, wavelength: 440.0, turns: 5, phase: 2.8 }, { height: 5.0, wavelength: 240.0, turns: 8, phase: 1.1 }] },
	{ level: 510.0, swells: [{ height: 12.0, wavelength: 520.0, turns: 6, phase: 0.3 }, { height: 6.0, wavelength: 270.0, turns: 10, phase: 2.5 }] },
	{ level: 565.0, swells: [{ height: 14.0, wavelength: 600.0, turns: 7, phase: 1.6 }, { height: 7.0, wavelength: 300.0, turns: 12, phase: 0.9 }] },
]

## How far apart the points of a band's top edge are, in pixels: close enough
## that the shortest swell reads as a curve, and few enough that a band is
## 123 corners, far under the native painter's 1024.
edge_spacing : F64
edge_spacing = 8.0

## How high a band's top edge is at `x`, `steps` into the cycle.
band_top_y : Band, { x : F64, steps : U64 } -> F64
band_top_y = |band, { x, steps }| {
	cycle = steps.to_f64() / cycle_steps.to_f64()
	band.swells.fold(
		band.level,
		|y, swell| y + swell.height * (F64.tau * (x / swell.wavelength + swell.turns.to_f64() * cycle) + swell.phase).sin(),
	)
}

## The corners of a band, `steps` into the cycle: its top edge left to right,
## then down to the bottom of the screen and back along it.
band_corners : Band, U64 -> List(Point)
band_corners = |band, steps| {
	count = (screen_width / edge_spacing).floor_to_u64_try() ?? crash "TidesApp.band_corners: the screen is a whole number of edge spacings"
	var $corners = List.with_capacity(count + 3)
	for k in 0..=count {
		x = k.to_f64() * edge_spacing
		$corners = $corners.append(Point.at(x, band_top_y(band, { x, steps })))
	}
	$corners.concat([Point.at(screen_width, screen_height), Point.at(0.0, screen_height)])
}

## Where a body crossing the sky is, `along` of the way across: out of the
## sea at the left, highest halfway, back into it at the right. At either end
## it is far enough under the horizon that the farthest band's troughs hide it.
arc_point : Fraction, { radius : F64, rise : F64 } -> Point
arc_point = |along, { radius, rise }| {
	u = along.to_f64()
	under = sea_level + radius + 6.0
	Point.at(120.0 + 720.0 * u, under - (under - sea_level + rise) * (F64.pi * u).sin())
}

## How far through the cycle the sun is up, from dawn to the middle of dusk,
## and the moon after it, through the night until just before dawn.
sun_set : F64
sun_set = 0.6

moon_rise : F64
moon_rise = 0.66

moon_set : F64
moon_set = 0.98

## The sun and its glow while it is up, and nothing after it has set.
sun_shapes : Fraction -> List(Shapes.Shape)
sun_shapes = |day|
	if day.to_f64() < sun_set {
		radius = 30.0
		center = arc_point(Fraction.clamp(day.to_f64() / sun_set), { radius, rise: 190.0 })
		glow = Shapes.halo({ center, radius: Pixels.of(130.0) }, Brush.with_alpha(RgbColor.of(0xFFD890), 0.35))
		[glow, Disc({ center, radius: Pixels.of(radius), fill: Brush.flat(RgbColor.of(0xFFE6A8)) })]
	} else {
		[]
	}

## The moon while it is up, and nothing by day.
moon_shapes : Fraction -> List(Shapes.Shape)
moon_shapes = |day|
	if day.to_f64() >= moon_rise and day.to_f64() < moon_set {
		radius = 18.0
		center = arc_point(Fraction.clamp((day.to_f64() - moon_rise) / (moon_set - moon_rise)), { radius, rise: 220.0 })
		[Disc({ center, radius: Pixels.of(radius), fill: Brush.flat(RgbColor.of(0xE8ECF4)) })]
	} else {
		[]
	}

# The cycle plays through its 3600 steps and comes back to the first model on
# the last, and not a step before.
expect {
	var $model = first_model
	var $returns = 0
	for _step in 0..<cycle_steps {
		$model = model_at_next_step($model, Input.none)
		$returns =
			if $model == first_model {
				$returns + 1
			} else {
				$returns
			}
	}
	$model == first_model and $returns == 1
}

# Every swell makes whole turns, so the water at the cycle's end is the water
# at its start, and the wrap shows no jump.
expect bands.all(|band| [0.0, 333.0, 960.0].all(|x| (band_top_y(band, { x, steps: cycle_steps }) - band_top_y(band, { x, steps: 0 })).abs() <= 1.0e-9))

# Through the cycle, sampled every ninth step, each band's top edge stays at
# least 10 pixels below the band behind it at every corner, so every band
# shows across the whole screen, and the nearest stays above the bottom.
expect {
	var $touches = 0
	for sample in 0..<(cycle_steps / 9) {
		steps = sample * 9
		tops = bands.map(|band| band_corners(band, steps).drop_last(2).map(|corner| corner.y.to_f64()))
		pairs = tops.drop_last(1).map2(tops.drop_first(1), |far, near| far.map2(near, |a, b| b - a >= 10.0).all(|clear| clear))
		nearest = tops.last() ?? crash "TidesApp: there are bands"
		$touches =
			if pairs.all(|clear| clear) and nearest.all(|y| y < screen_height) {
				$touches
			} else {
				$touches + 1
			}
	}
	$touches == 0
}

# Every frame is in the shapes the native painter draws, with at most one
# Radial fill, the sun's glow, and every polygon under its 1024 corners.
expect [0, 900, 1500, 2200, 2700, 3599].all(
	|steps| {
		shapes = TidesApp.frame_shapes({ steps, play: Playing })
		radials = shapes.count_if(
			|shape|
				match shape {
					Disc(disc) => is_radial(disc.fill)
					Triangle(_) | Quad(_) | Polygon(_) | Blend(_) | View(_) | Image(_) | Text(_) => False
				},
		)
		polygons_fit = shapes.all(
			|shape|
				match shape {
					Polygon(polygon) => polygon.corners.len() < 1024
					Triangle(_) | Quad(_) | Disc(_) | Blend(_) | View(_) | Image(_) | Text(_) => True
				},
		)
		radials <= 1 and polygons_fit
	},
)

## Whether a fill is one of the Radial gradients the native painter spends
## the most on.
is_radial : Brush.Fill -> Bool
is_radial = |fill|
	match fill {
		Radial(_) => True
		Flat(_) | Span(_) | Linear(_) | Ellipse(_) | Glow(_) => False
	}

# The sun is up by day and the moon by night, never both, and neither at the
# very turn of the cycle, so a restart at dawn shows no jump.
expect sun_shapes(day_at(900)).len() == 2 and moon_shapes(day_at(900)).is_empty()
expect sun_shapes(day_at(3000)).is_empty() and moon_shapes(day_at(3000)).len() == 1
expect moon_shapes(day_at(3599)).is_empty()
expect arc_point(Fraction.zero, { radius: 30.0, rise: 190.0 }).y.to_f64() - 30.0 > sea_level + 5.0

# The controls. `mid` is a thousand steps in and playing.
mid_model : TidesApp.Model
mid_model = { steps: 1000, play: Playing }

# With no key struck the cycle plays a step, and a held key that was not
# struck at this step changes nothing.
expect model_at_next_step(mid_model, Input.none) == { steps: 1001, play: Playing }
expect model_at_next_step(mid_model, Input.none.with_key_down(KeySpace)) == { steps: 1001, play: Playing }
expect model_at_next_step(mid_model, Input.none.with_key_down(KeyR)) == { steps: 1001, play: Playing }

# Space pauses where it is, a paused step holds still, and a second Space
# resumes from the same step.
expect {
	space = Input.none.with_key_pressed(KeySpace)
	paused = model_at_next_step(mid_model, space)
	paused == { steps: 1000, play: Paused }
		and model_at_next_step(paused, Input.none) == paused
		and model_at_next_step(paused, space) == mid_model
}

# R goes back to dawn and plays, from playing or paused, and wins over Space.
expect {
	r = Input.none.with_key_pressed(KeyR)
	model_at_next_step(mid_model, r) == first_model
		and model_at_next_step({ ..mid_model, play: Paused }, r) == first_model
		and model_at_next_step(mid_model, r.with_key_pressed(KeySpace)) == first_model
}
