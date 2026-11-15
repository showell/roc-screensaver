## RoadTrees places the conifers along a road that never ends. A tree stands
## each side of the road about every `tree_spacing`, as in Safari, and each one
## is a function of its side and its place in the line, worked out from a fixed
## seed whenever it is asked for. So the road holds no trees in memory: a frame
## asks for the ones between two distances along, and the same tree comes back
## the same every time.
##
## The pairs alternate between a green tree and the stretch's accent, small and
## green, or red, or gold, as Safari's segments do, and a gold tree stands
## farther from the road. Each stretch of `pairs_a_stretch` pairs draws its
## accent from the seed, and each tree is nudged along by up to `most_nudge`.
import Conifer

RoadTrees :: [].{

	## Which side of the road a tree stands on, as the camera looks down it.
	Side : [Left, Right]

	## A tree beside the road: its side, its place in that side's line, how far
	## along the road and across it it stands in metres (across negative on the
	## left), and its kind.
	RoadTree : {
		side : RoadTrees.Side,
		place : U64,
		along : F64,
		across : F64,
		conifer : Conifer,
	}

	## The tree at `place` in the line on `side`.
	tree_at : RoadTrees.Side, U64 -> RoadTrees.RoadTree
	tree_at = |side, place| {
		conifer = conifer_at(place)
		nudge = (unit_draw(tree_key(side, place)) * 2.0 - 1.0) * most_nudge
		distance_out = tree_line_distance(conifer)
		across =
			match side {
				Left => 0.0 - distance_out
				Right => distance_out
			}
		{
			side,
			place,
			along: first_along + place.to_f64() * tree_spacing + nudge,
			across,
			conifer,
		}
	}

	## The trees on both sides whose `along` is from `nearest` up to
	## `farthest`, in no particular order.
	trees_between : { nearest : F64, farthest : F64 } -> List(RoadTrees.RoadTree)
	trees_between = |{ nearest, farthest }| {
		first_place = place_at_or_before(nearest - most_nudge)
		last_place = place_at_or_before(farthest + most_nudge)
		is_in_range = |tree| tree.along >= nearest and tree.along <= farthest
		var $trees = []
		for place in first_place..=last_place {
			$trees = $trees.append(RoadTrees.tree_at(Left, place)).append(RoadTrees.tree_at(Right, place))
		}
		$trees.keep_if(is_in_range)
	}

	## The side across the road from `side`.
	other_side : RoadTrees.Side -> RoadTrees.Side
	other_side = |side|
		match side {
			Left => Right
			Right => Left
		}

	## The most a tree is nudged along the road from its even place, either
	## way, chosen by eye.
	most_nudge : F64
	most_nudge = 6.0
}

## How far apart the pairs stand along the road, as in Safari.
tree_spacing : F64
tree_spacing = 30.0

## Where the first pair stands along the road.
first_along : F64
first_along = 6.0

## How far from the middle of the road a tree stands: Safari's half road of
## 2 m plus 1.5 m, and four times that 1.5 m for a gold tree.
tree_line_distance : Conifer -> F64
tree_line_distance = |conifer|
	match conifer {
		Gold => road_half_width + tree_road_offset * 4.0
		Green | SmallGreen | Red => road_half_width + tree_road_offset
	}

road_half_width : F64
road_half_width = 2.0

tree_road_offset : F64
tree_road_offset = 1.5

## How many pairs share one accent, chosen by eye.
pairs_a_stretch : U64
pairs_a_stretch = 8

## The seed every tree is drawn from. Any value gives an endless road; this
## one is fixed so that every run shows the same one.
seed : U64
seed = 20261115

## The conifer at `place`: green at an even place, the stretch's accent at an
## odd one.
conifer_at : U64 -> Conifer
conifer_at = |place|
	if place % 2 == 0 {
		Conifer.Green
	} else {
		stretch = place // pairs_a_stretch
		match draw(stretch * 2 + 1) % 3 {
			0 => Conifer.SmallGreen
			1 => Conifer.Red
			_ => Conifer.Gold
		}
	}

## The key a tree's nudge is drawn from, apart from every stretch's key, which
## is odd.
tree_key : RoadTrees.Side, U64 -> U64
tree_key = |side, place|
	match side {
		Left => place * 4
		Right => place * 4 + 2
	}

## The last place whose even position is at or before `along`, and the first
## place for any `along` before it.
place_at_or_before : F64 -> U64
place_at_or_before = |along| {
	steps = (along - first_along) / tree_spacing
	if steps <= 0.0 {
		0
	} else {
		steps.floor_to_u64_try() ?? crash "RoadTrees.place_at_or_before: a road longer than a U64 of places"
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

# A tree is the same each time it is asked for.
expect RoadTrees.tree_at(Left, 7) == RoadTrees.tree_at(Left, 7)

# The two lines stand either side of the road, and a nudge stays within its
# bound.
expect
	[0, 1, 2, 3, 50, 1000].all(
		|place| {
			left = RoadTrees.tree_at(Left, place)
			right = RoadTrees.tree_at(Right, place)
			even = first_along + place.to_f64() * tree_spacing
			left.across < 0.0
				and right.across > 0.0
				and (left.along - even).abs() <= RoadTrees.most_nudge
				and (right.along - even).abs() <= RoadTrees.most_nudge
		},
	)

# Even places are green, and both sides of a pair are the same kind.
expect [0, 2, 4, 100].all(|place| RoadTrees.tree_at(Right, place).conifer == Conifer.Green)
expect [1, 3, 99].all(|place| RoadTrees.tree_at(Left, place).conifer == RoadTrees.tree_at(Right, place).conifer)

# Every tree between two distances is in range, and the trees just inside the
# ends are among them.
expect {
	trees = RoadTrees.trees_between({ nearest: 100.0, farthest: 400.0 })
	trees.all(|tree| tree.along >= 100.0 and tree.along <= 400.0)
		and trees.len() >= 16
		and trees.len() <= 24
}

# A range before the road's start finds only the trees from its start.
expect RoadTrees.trees_between({ nearest: -500.0, farthest: -100.0 }) == []

expect place_at_or_before(-10.0) == 0
expect place_at_or_before(36.0) == 1
expect place_at_or_before(35.9) == 0
