## BubblesApp is the bubbles screensaver as a value a runner can play:
## translucent bubbles in Roc's purples rise from the bottom of a dark violet
## screen, wobbling side to side, and each one fades away or pops near the top
## while new ones keep coming, forever.
##
## The model is only a count of steps and whether it plays. Every bubble is
## worked out from that count: bubble `k` is born at step `k * spawn_steps`, and
## its size, speed, wobble, colour and ending come from a hash of `k`. So the
## frames are the same on every run and every platform, and the model never
## grows however long it plays.
##
## Space pauses and resumes, and R restarts. With no key struck it plays on by
## itself, as a screensaver must. Every shape is a disc with a flat fill or the
## backdrop's linear gradient, each of which the native painter draws.
import lib.Brush
import lib.CanvasApp
import lib.Input
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes

BubblesApp :: [].{
	Model : { steps : U64, play : BubblesApp.Play }

	## Whether the bubbles move on at each step, or hold still for the viewer.
	Play : [Playing, Paused]

	## One bubble, as its hash makes it. `x` is the middle of its wobble.
	Bubble : {
		birth_step : U64,
		x : F64,
		radius : F64,
		speed : F64,
		wobble_width : F64,
		wobble_steps : F64,
		wobble_phase : F64,
		color : RgbColor,
		ending : BubblesApp.Ending,
	}

	## How a bubble leaves: it fades out as it nears the top, or it pops at
	## `height` pixels from the top.
	Ending : [Fades, Pops({ height : F64 })]

	## Where a bubble is at one step of the clock. `fade` runs from 1, fully
	## seen, to 0; `burst` from 0, the pop's first step, toward 1.
	Moment : [
		Unborn,
		Rising({ center : Point, fade : F64 }),
		Bursting({ center : Point, burst : F64 }),
		Gone,
	]

	canvas_app : CanvasApp.CanvasApp(BubblesApp.Model)
	canvas_app = {
		size: { width: screen_width, height: screen_height },
		frames_a_second: 30,
		init: first_model,
		model_at_next_step: CanvasApp.untimed_model_at_next_step(model_at_next_step),
		frame_shapes: BubblesApp.frame_shapes,
		sounds: |_model| 0,
		tones: [],
		title: "Bubbles",
		controls: [
			{ keys: "Space", does: "pauses and resumes" },
			{ keys: "R", does: "restarts" },
		],
	}

	## The backdrop, then every bubble on the screen, the smaller ones first so
	## the larger ones float in front.
	frame_shapes : BubblesApp.Model -> List(Shapes.Shape)
	frame_shapes = |model| {
		clock = model.steps + life_steps
		bubbles = BubblesApp.bubbles_born_by(clock).sort_with(
			|a, b|
				if a.radius < b.radius {
					Before
				} else if a.radius > b.radius {
					After
				} else {
					Same
				},
		)
		[backdrop].concat(bubbles.join_map(|bubble| bubble_shapes(bubble, BubblesApp.moment_at(bubble, clock))))
	}

	## The bubbles born in the last `life_steps` before `clock`, the only ones
	## that can still be on the screen.
	bubbles_born_by : U64 -> List(BubblesApp.Bubble)
	bubbles_born_by = |clock| {
		first = (clock - life_steps) // spawn_steps
		last = clock // spawn_steps
		var $out = []
		for k in first..=last {
			$out = $out.append(BubblesApp.numbered_bubble(k))
		}
		$out
	}

	## Bubble `k`, its look and its ending chosen by a hash of `k`. Half are
	## small and quick, a third middling, and the rest large and slow.
	numbered_bubble : U64 -> BubblesApp.Bubble
	numbered_bubble = |k| {
		size = share({ bubble: k, field: 0 })
		look =
			if size < 0.5 {
				{ radius: 7.0, grow: 7.0, speed: 1.5, wobble_width: 18.0 }
			} else if size < 0.85 {
				{ radius: 17.0, grow: 11.0, speed: 1.1, wobble_width: 13.0 }
			} else {
				{ radius: 33.0, grow: 13.0, speed: 0.75, wobble_width: 9.0 }
			}
		ending =
			if share({ bubble: k, field: 1 }) < 0.4 {
				Pops({ height: 70.0 + 130.0 * share({ bubble: k, field: 2 }) })
			} else {
				Fades
			}
		{
			birth_step: k * spawn_steps,
			x: 40.0 + (screen_width - 80.0) * share({ bubble: k, field: 3 }),
			radius: look.radius + look.grow * share({ bubble: k, field: 4 }),
			speed: look.speed + 0.4 * share({ bubble: k, field: 5 }),
			wobble_width: look.wobble_width * (0.5 + share({ bubble: k, field: 6 })),
			wobble_steps: 60.0 + 70.0 * share({ bubble: k, field: 7 }),
			wobble_phase: F64.tau * share({ bubble: k, field: 8 }),
			color: purples.get(hash_of(k * 16 + 9) % purples.len()) ?? crash "BubblesApp.numbered_bubble: a remainder is an index",
			ending,
		}
	}

	## Where `bubble` is at step `clock`: rising from just below the bottom edge,
	## then fading out near the top or bursting at its height, then gone.
	moment_at : BubblesApp.Bubble, U64 -> BubblesApp.Moment
	moment_at = |bubble, clock|
		if clock < bubble.birth_step {
			Unborn
		} else {
			age = (clock - bubble.birth_step).to_f64()
			y = screen_height + bubble.radius - bubble.speed * age
			wobble = bubble.wobble_width * (bubble.wobble_phase + F64.tau * age / bubble.wobble_steps).sin()
			center = Point.at(bubble.x + wobble, y)
			match bubble.ending {
				Fades => {
					fade = ((y - fade_bottom) / (fade_top - fade_bottom)).min(1.0)
					if fade > 0.0 {
						Rising({ center, fade })
					} else {
						Gone
					}
				}
				Pops({ height }) => {
					steps_past = (height - y) / bubble.speed
					if steps_past < 0.0 {
						Rising({ center, fade: 1.0 })
					} else if steps_past < burst_steps {
						Bursting({ center: Point.at(bubble.x + wobble, height), burst: steps_past / burst_steps })
					} else {
						Gone
					}
				}
			}
		}
}

screen_width : F64
screen_width = 960.0

screen_height : F64
screen_height = 600.0

## A bubble is born every this many steps, three a second.
spawn_steps : U64
spawn_steps = 10

## No bubble lasts longer than this: the slowest, largest one takes about 880
## steps to rise to its fading line. An expect holds every bubble to it.
life_steps : U64
life_steps = 1000

## A fading bubble is whole below `fade_top` and gone at `fade_bottom`.
fade_top : F64
fade_top = 200.0

fade_bottom : F64
fade_bottom = 30.0

## How many steps a pop's droplets fly out for.
burst_steps : F64
burst_steps = 9.0

## Roc's purples, from its own logo's violet to a pale lilac.
purples : List(RgbColor)
purples = [0x7C38F5, 0x9B6BF7, 0xB794FF, 0x5A2DB0, 0xD4BFFF].map(RgbColor.of)

first_model : BubblesApp.Model
first_model = { steps: 0, play: Playing }

## The model after one step. A key acts on the step it is struck, never while
## it is held; R is read before Space, so a step that strikes both restarts.
model_at_next_step : BubblesApp.Model, Input.Snapshot -> BubblesApp.Model
model_at_next_step = |model, input|
	if input.key_pressed(KeyR) {
		first_model
	} else if input.key_pressed(KeySpace) {
		{ ..model, play: toggle_of(model.play) }
	} else {
		match model.play {
			Playing => { ..model, steps: model.steps + 1 }
			Paused => model
		}
	}

toggle_of : BubblesApp.Play -> BubblesApp.Play
toggle_of = |play|
	match play {
		Playing => Paused
		Paused => Playing
	}

## The night sky the bubbles rise through, darkest at the top.
backdrop : Shapes.Shape
backdrop = Shapes.rectangle({
	top_left: Point.at(0.0, 0.0),
	width: Pixels.of(screen_width),
	height: Pixels.of(screen_height),
	fill: Brush.linear_gradient({
		stops: {
			start_color: Brush.opaque_rgba(RgbColor.of(0x120826)),
			end_color: Brush.opaque_rgba(RgbColor.of(0x2E1563)),
			start_offset: 0.0,
			end_offset: 1.0,
		},
		start_point: Point.at(0.0, 0.0),
		end_point: Point.at(0.0, screen_height),
	}),
})

## A rising bubble is its colour, a darker middle that leaves a rim, and a
## glint; a bursting one is six droplets flying out and fading.
bubble_shapes : BubblesApp.Bubble, BubblesApp.Moment -> List(Shapes.Shape)
bubble_shapes = |bubble, moment|
	match moment {
		Rising({ center, fade }) => {
			r = bubble.radius
			glint = Point.at(center.x.to_f64() - 0.38 * r, center.y.to_f64() - 0.38 * r)
			[
				disc(center, { radius: r, fill: Brush.with_alpha(bubble.color, 0.34 * fade) }),
				disc(center, { radius: 0.8 * r, fill: Brush.with_alpha(RgbColor.of(0x1A0B38), 0.3 * fade) }),
				disc(glint, { radius: 0.2 * r, fill: Brush.with_alpha(RgbColor.of(0xFFFFFF), 0.6 * fade) }),
			]
		}
		Bursting({ center, burst }) => {
			reach = bubble.radius * (1.0 + 0.6 * burst)
			fill = Brush.with_alpha(bubble.color, 0.7 * (1.0 - burst))
			[0.0, 1.0, 2.0, 3.0, 4.0, 5.0].map(
				|n| {
					angle = F64.tau * n / 6.0
					spot = Point.at(center.x.to_f64() + reach * angle.cos(), center.y.to_f64() + reach * angle.sin())
					disc(spot, { radius: 2.0 + 0.08 * bubble.radius, fill })
				},
			)
		}
		Unborn | Gone => []
	}

disc : Point, { radius : F64, fill : Brush.Rgba } -> Shapes.Shape
disc = |center, { radius, fill }| Disc({ center, radius: Pixels.of(radius), fill: Flat(fill) })

## A share from 0 up to 1, the same for the same bubble and field every time.
share : { bubble : U64, field : U64 } -> F64
share = |{ bubble, field }| (hash_of(bubble * 16 + field) % 10_000).to_f64() / 10_000.0

## A 64-bit hash that spreads neighbouring numbers far apart (SplitMix64's
## finish), so bubble `k` and bubble `k + 1` look nothing alike.
hash_of : U64 -> U64
hash_of = |seed| {
	a = seed.plus_wrap(0x9E3779B97F4A7C15)
	b = a.bitwise_xor(a.shr_zf_wrap(30)).times_wrap(0xBF58476D1CE4E5B9)
	c = b.bitwise_xor(b.shr_zf_wrap(27)).times_wrap(0x94D049BB133111EB)
	c.bitwise_xor(c.shr_zf_wrap(31))
}

## The moments of bubble `k` at every age from its birth to `life_steps`.
moments_of : U64 -> List(BubblesApp.Moment)
moments_of = |k| {
	bubble = BubblesApp.numbered_bubble(k)
	var $out = []
	for age in 0..=life_steps {
		$out = $out.append(BubblesApp.moment_at(bubble, bubble.birth_step + age))
	}
	$out
}

## Whether a bubble's moments go as they should: it rises from below the
## screen, always upward, then bursts (only if it pops) and is gone for good
## before `life_steps`.
is_rise_then_end : BubblesApp.Bubble, List(BubblesApp.Moment) -> Bool
is_rise_then_end = |bubble, moments| {
	rising_ys = moments.keep_oks(
		|moment|
			match moment {
				Rising({ center, .. }) => Ok(center.y.to_f64())
				Unborn | Bursting(_) | Gone => Err(NotRising)
			},
	)
	bursts = moments.keep_oks(
		|moment|
			match moment {
				Bursting(_) => Ok({})
				Unborn | Rising(_) | Gone => Err(NotBursting)
			},
	).len()
	is_from_below =
		match rising_ys {
			[first_y, ..] => first_y >= screen_height
			[] => False
		}
	is_upward = rising_ys.map2(rising_ys.drop_first(1), |lower, higher| higher < lower).all(|up| up)
	ending_is_kept =
		match bubble.ending {
			Fades => bursts == 0
			Pops(_) => bursts > 0 and bursts <= 10
		}
	order = moments.map(
		|moment|
			match moment {
				Unborn => 0
				Rising(_) => 1
				Bursting(_) => 2
				Gone => 3
			},
	)
	is_in_order = order.map2(order.drop_first(1), |a, b| a <= b).all(|ok| ok)
	is_from_below and is_upward and ending_is_kept and is_in_order and moments.last() == Ok(Gone)
}

# Every one of the first 600 bubbles rises from below the screen, steadily
# upward, ends as its hash says and is gone within `life_steps`, which is what
# lets a frame look only that far back.
expect List.from_iter(U64.until(0, 600)).all(|k| is_rise_then_end(BubblesApp.numbered_bubble(k), moments_of(k)))

# Before its birth a bubble is unborn, and at its birth it rises.
expect {
	bubble = BubblesApp.numbered_bubble(7)
	BubblesApp.moment_at(bubble, bubble.birth_step - 1) == Unborn
		and BubblesApp.moment_at(bubble, bubble.birth_step) != Unborn
}

# Both endings, all three sizes and every purple turn up among the first 200.
expect {
	bubbles = List.from_iter(U64.until(0, 200)).map(BubblesApp.numbered_bubble)
	pops = bubbles.count_if(|b| b.ending != Fades)
	small = bubbles.count_if(|b| b.radius < 15.0)
	large = bubbles.count_if(|b| b.radius >= 33.0)
	pops > 40 and pops < 120 and small > 60 and large > 10
		and purples.all(|purple| bubbles.any(|b| b.color == purple))
}

## How many bubbles are on the screen after `steps` steps.
bubbles_seen : U64 -> U64
bubbles_seen = |steps| {
	clock = steps + life_steps
	BubblesApp.bubbles_born_by(clock).count_if(
		|bubble|
			match BubblesApp.moment_at(bubble, clock) {
				Rising(_) | Bursting(_) => True
				Unborn | Gone => False
			},
	)
}

# The screen is full of bubbles from the first frame, and stays as full however
# long it plays.
expect [0, 1, 4_321, 10_000_000].all(|steps| bubbles_seen(steps) >= 25 and bubbles_seen(steps) <= 70)

# Every shape is the backdrop's gradient or a disc with a flat fill, which the
# native painter draws as it is: no radial fill, no text, no picture.
expect [0, 355, 9_999].all(
	|steps| {
		shapes = BubblesApp.frame_shapes({ steps, play: Playing })
		shapes.first() == Ok(backdrop)
			and shapes.drop_first(1).all(
				|shape|
					match shape {
						Disc({ fill: Flat(_), .. }) => True
						Disc(_) | Triangle(_) | Quad(_) | Polygon(_) | Blend(_) | View(_) | Image(_) | Text(_) => False
					},
			)
	},
)

# A step plays on; Space pauses and a paused step holds still, a held Space
# does nothing more, and a second Space resumes.
expect {
	space = Input.none.with_key_pressed(KeySpace)
	mid = { steps: 500, play: Playing }
	paused = model_at_next_step(mid, space)
	resumed = model_at_next_step(paused, space)
	model_at_next_step(mid, Input.none) == { steps: 501, play: Playing }
		and paused == { steps: 500, play: Paused }
		and model_at_next_step(paused, Input.none) == paused
		and model_at_next_step(paused, Input.none.with_key_down(KeySpace)) == paused
		and resumed == mid
}

# R restarts from a playing or a paused model, even with Space struck too, and
# a held R does not.
expect {
	r = Input.none.with_key_pressed(KeyR)
	both = r.with_key_pressed(KeySpace)
	model_at_next_step({ steps: 800, play: Playing }, r) == first_model
		and model_at_next_step({ steps: 800, play: Paused }, r) == first_model
		and model_at_next_step({ steps: 800, play: Paused }, both) == first_model
		and model_at_next_step({ steps: 800, play: Playing }, Input.none.with_key_down(KeyR)) == { steps: 801, play: Playing }
}
