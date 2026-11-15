## RoadLamps places the lamps along a road that never ends. A lamp stands each
## side of the road about every `lamp_spacing`, and each one is a function of
## its side and its place in the line, worked out from a fixed seed whenever it
## is asked for. So the road holds no lamps in memory: a frame asks for the ones
## between two distances along, and the same lamp comes back the same every
## time.
##
## The pairs alternate between an amber lamp and the stretch's accent, rose or
## mint. Each stretch of `pairs_a_stretch` pairs draws its accent from the seed,
## and each lamp is nudged along by up to `most_nudge`.
##
## This file is adapted from the bird screensaver's RoadTrees, itself after
## Safari's tree lines, with lamps for trees.
import Lantern

RoadLamps :: [].{

	## Which side of the road a lamp stands on, as the camera looks down it.
	Side : [Left, Right]

	## A lamp beside the road: its side, its place in that side's line, how far
	## along the road and across it it stands in metres (across negative on the
	## left), and its kind.
	RoadLamp : {
		side : RoadLamps.Side,
		place : U64,
		along : F64,
		across : F64,
		lantern : Lantern,
	}

	## The lamp at `place` in the line on `side`.
	lamp_at : RoadLamps.Side, U64 -> RoadLamps.RoadLamp
	lamp_at = |side, place| {
		nudge = (unit_draw(lamp_key(side, place)) * 2.0 - 1.0) * most_nudge
		across =
			match side {
				Left => 0.0 - lamp_line_distance
				Right => lamp_line_distance
			}
		{
			side,
			place,
			along: RoadLamps.even_along(place) + nudge,
			across,
			lantern: lantern_at(place),
		}
	}

	## The lamps on both sides whose `along` is from `nearest` up to
	## `farthest`, in no particular order.
	lamps_between : { nearest : F64, farthest : F64 } -> List(RoadLamps.RoadLamp)
	lamps_between = |{ nearest, farthest }| {
		first_place = place_at_or_before(nearest - most_nudge)
		last_place = place_at_or_before(farthest + most_nudge)
		is_in_range = |lamp| lamp.along >= nearest and lamp.along <= farthest
		var $lamps = []
		for place in first_place..=last_place {
			$lamps = $lamps.append(RoadLamps.lamp_at(Left, place)).append(RoadLamps.lamp_at(Right, place))
		}
		$lamps.keep_if(is_in_range)
	}

	## Where the pair at `place` would stand along the road with no nudge.
	even_along : U64 -> F64
	even_along = |place| first_along + place.to_f64() * RoadLamps.lamp_spacing

	## How far apart the pairs stand along the road, chosen by eye.
	lamp_spacing : F64
	lamp_spacing = 30.0

	## The side across the road from `side`.
	other_side : RoadLamps.Side -> RoadLamps.Side
	other_side = |side|
		match side {
			Left => Right
			Right => Left
		}

	## The most a lamp is nudged along the road from its even place, either
	## way, chosen by eye.
	most_nudge : F64
	most_nudge = 6.0

	## How far from the middle of the road the lamps stand: a half road of
	## 2 m plus 1.5 m of verge.
	lamp_line_distance : F64
	lamp_line_distance = 3.5
}

## Where the first pair stands along the road.
first_along : F64
first_along = 6.0

## How many pairs share one accent, chosen by eye.
pairs_a_stretch : U64
pairs_a_stretch = 6

## The seed every lamp is drawn from. Any value gives an endless road; this
## one is fixed so that every run shows the same one.
seed : U64
seed = 20261115

## The lantern at `place`: amber at an even place, the stretch's accent at an
## odd one.
lantern_at : U64 -> Lantern
lantern_at = |place|
	if place % 2 == 0 {
		Lantern.Amber
	} else if draw((place // pairs_a_stretch) * 2 + 1) % 2 == 0 {
		Lantern.Rose
	} else {
		Lantern.Mint
	}

## The key a lamp's nudge is drawn from, apart from every stretch's key, which
## is odd.
lamp_key : RoadLamps.Side, U64 -> U64
lamp_key = |side, place|
	match side {
		Left => place * 4
		Right => place * 4 + 2
	}

## The last place whose even position is at or before `along`, and the first
## place for any `along` before it.
place_at_or_before : F64 -> U64
place_at_or_before = |along| {
	steps = (along - first_along) / RoadLamps.lamp_spacing
	if steps <= 0.0 {
		0
	} else {
		steps.floor_to_u64_try() ?? crash "RoadLamps.place_at_or_before: a road longer than a U64 of places"
	}
}

mask : U64
mask = 4294967295

## A linear congruential step, masked to 32 bits so its multiply never
## overflows, as in roc-apps' Random.
turn : U64 -> U64
turn = |n| (n.bitwise_and(mask) * 1664525 + 1013904223).bitwise_and(mask)

## 24 well-mixed bits drawn for `key` from the seed, from the top of the word,
## where an LCG's bits are best mixed.
draw : U64 -> U64
draw = |key| turn(turn(turn(seed + key))).shr_wrap(8)

## A draw for `key` as a number from 0 up to 1.
unit_draw : U64 -> F64
unit_draw = |key| draw(key).to_f64() / 16777216.0

# A lamp is the same each time it is asked for.
expect RoadLamps.lamp_at(Left, 7) == RoadLamps.lamp_at(Left, 7)

# The two lines stand either side of the road, and a nudge stays within its
# bound.
expect
	[0, 1, 2, 3, 50, 1000].all(
		|place| {
			left = RoadLamps.lamp_at(Left, place)
			right = RoadLamps.lamp_at(Right, place)
			even = RoadLamps.even_along(place)
			left.across < 0.0
				and right.across > 0.0
				and (left.along - even).abs() <= RoadLamps.most_nudge
				and (right.along - even).abs() <= RoadLamps.most_nudge
		},
	)

# Even places are amber, odd ones an accent, and both sides of a pair are the
# same kind.
expect [0, 2, 4, 100].all(|place| RoadLamps.lamp_at(Right, place).lantern == Lantern.Amber)
expect [1, 3, 99].all(|place| RoadLamps.lamp_at(Left, place).lantern != Lantern.Amber)
expect [1, 3, 99].all(|place| RoadLamps.lamp_at(Left, place).lantern == RoadLamps.lamp_at(Right, place).lantern)

# Every lamp between two distances is in range, and the lamps just inside the
# ends are among them.
expect {
	lamps = RoadLamps.lamps_between({ nearest: 100.0, farthest: 400.0 })
	lamps.all(|lamp| lamp.along >= 100.0 and lamp.along <= 400.0)
		and lamps.len() >= 16
		and lamps.len() <= 24
}

# A range before the road's start finds only the lamps from its start.
expect RoadLamps.lamps_between({ nearest: -500.0, farthest: -100.0 }) == []

expect place_at_or_before(-10.0) == 0
expect place_at_or_before(36.0) == 1
expect place_at_or_before(35.9) == 0
