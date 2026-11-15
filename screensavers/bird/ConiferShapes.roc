## A conifer on the screen: a trunk under eight tiers of foliage, each tier a
## flat triangle. A tree near the camera gets a shaded trunk, which looks round.
##
## This file is adapted from roc-apps (`canvas_apps/safari/TreeShapes.roc`) on
## 2026-11-15, and it is allowed to drift from it. The tiers, the shares of the
## tree's height and the trunk are Safari's, copied. Safari draws a near
## tree's tiers as cones seen from the camera; here every tier is the flat
## triangle Safari draws for a far tree, which spares the screensaver Safari's
## convex hull and its camera.
import Conifer
import lib.Brush
import lib.Fraction
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes

ConiferShapes :: [].{

	## Where a tree stands on the screen: its foot's middle, and how tall it
	## looks.
	Upright : { foot : Point, height_on_screen : Pixels }

	## The tree standing at `upright`, `forward` metres from the camera: its
	## trunk, then its tiers top to bottom.
	tree_shapes : ConiferShapes.Upright, { conifer : Conifer, forward : F64 } -> List(Shapes.Shape)
	tree_shapes = |outline, { conifer, forward }| {
		trunk = trunk_shape(outline, trunk_finish_of(forward))
		foliage_color = conifer.foliage_color()
		[trunk].concat(tiers.map(|tier| tier_triangle(outline, { tier, foliage_color })))
	}
}

## The tree is drawn 136 parts tall, and the shares below are parts of that,
## all chosen by eye.
tree_parts : U64
tree_parts = 136

## A tree nearer than this many metres gets a shaded trunk, which looks round.
## Past it, a trunk is only a few pixels wide on the screen, too narrow for the
## shading to show, so it is drawn flat.
round_trunk_reach : F64
round_trunk_reach = 60.0

## How a tree's trunk is drawn: shaded, which looks round, or flat.
TrunkFinish : [Shaded, Flat]

## How a tree's trunk is drawn `forward` metres away.
trunk_finish_of : F64 -> TrunkFinish
trunk_finish_of = |forward|
	if forward < round_trunk_reach {
		Shaded
	} else {
		Flat
	}

## How tall a tree's crown looks on the screen.
crown_height : ConiferShapes.Upright -> Pixels
crown_height = |outline| outline.height_on_screen.scaled_by(crown_height_share)

## Where the top of a tree's crown is on the screen: the tree's tip.
crown_top_y : ConiferShapes.Upright -> Pixels
crown_top_y = |outline| outline.foot.y.minus(outline.height_on_screen)

## How far the crown reaches either side of the trunk at its widest, on the
## screen.
crown_half_width : ConiferShapes.Upright -> Pixels
crown_half_width = |outline| outline.height_on_screen.scaled_by(crown_half_width_share)

## One tier of the crown: where its top and its bottom are, as fractions of
## the crown's height down from its top, and how wide its bottom is, as a
## fraction of the crown's width.
Tier : {
	top : Fraction,
	bottom : Fraction,
	width : Fraction,
}

## How wide each tier's bottom is, top tier first, as a fraction of the crown's
## width, chosen by eye.
tier_widths : List(Fraction)
tier_widths = [0.35, 0.44, 0.53, 0.63, 0.72, 0.81, 0.91, 1.0].map(Fraction.of)

## The tiers, top to bottom. Each starts a tenth of the crown lower than the
## one above and runs three tenths down, so each overlaps the next.
tiers : List(Tier)
tiers = tier_widths.map_with_index(
	|width, index| {
		top: Fraction.of(index.to_f64() / 10.0),
		bottom: Fraction.of((index.to_f64() + 3.0) / 10.0),
		width,
	},
)

trunk_color : RgbColor
trunk_color = RgbColor.of(0x5A3E22)

## Of the tree's parts, 55 are trunk below the crown, chosen by eye.
trunk_height_share : Fraction
trunk_height_share = Fraction.of(55.0 / tree_parts.to_f64())

## The crown is the rest of the tree, so its tip is the tree's height.
crown_height_share : Fraction
crown_height_share = trunk_height_share.complement()

## The crown's widest half-width, as a fraction of the tree's height: 36
## parts, chosen by eye.
crown_half_width_share : Fraction
crown_half_width_share = Fraction.of(36.0 / tree_parts.to_f64())

## The trunk's width, as a fraction of the tree's height: 10 parts, chosen by
## eye.
trunk_width_share : Fraction
trunk_width_share = Fraction.of(10.0 / tree_parts.to_f64())

## However far off a tree is, its trunk is this wide.
min_trunk_width : Pixels
min_trunk_width = Pixels.of(1.0)

## How far the trunk runs up inside the crown, as a fraction of the tree's
## height, so that no sky shows between them: 6.25 parts, chosen by eye.
trunk_overlap_share : Fraction
trunk_overlap_share = Fraction.of(6.25 / tree_parts.to_f64())

## The trunk under the crown of the tree whose outline is `outline`.
trunk_shape : ConiferShapes.Upright, TrunkFinish -> Shapes.Shape
trunk_shape = |outline, finish| {
	width = outline.height_on_screen.scaled_by(trunk_width_share).max(min_trunk_width)
	below_crown = outline.height_on_screen.scaled_by(trunk_height_share)
	height = below_crown.plus(outline.height_on_screen.scaled_by(trunk_overlap_share))
	left = outline.foot.x.minus(width.divided_by(2.0))
	fill =
		match finish {
			Shaded => Brush.width_shade(
				{ min_x: left, max_x: left.plus(width) },
				{ color: trunk_color, strength: Fraction.whole },
			)
			Flat => Brush.flat(trunk_color)
		}
	Shapes.rectangle({
		top_left: { x: left, y: outline.foot.y.minus(height) },
		width,
		height,
		fill,
	})
}

## A tier as a flat triangle: its apex at the tier's top, its base across its
## bottom.
tier_triangle : ConiferShapes.Upright, { tier : Tier, foliage_color : RgbColor } -> Shapes.Shape
tier_triangle = |outline, { tier, foliage_color }| {
	crown_top = crown_top_y(outline)
	bottom_y = crown_top.plus(crown_height(outline).scaled_by(tier.bottom))
	top_y = crown_top.plus(crown_height(outline).scaled_by(tier.top))
	half_base = crown_half_width(outline).scaled_by(tier.width)
	Triangle({
		first: { x: outline.foot.x, y: top_y },
		second: { x: outline.foot.x.plus(half_base), y: bottom_y },
		third: { x: outline.foot.x.minus(half_base), y: bottom_y },
		fill: Brush.flat(foliage_color),
	})
}

# A tree is a trunk and eight tiers, and its top tier's apex is the tree's tip.
expect {
	outline = { foot: Point.at(480.0, 600.0), height_on_screen: Pixels.of(136.0) }
	shapes = ConiferShapes.tree_shapes(outline, { conifer: Conifer.Green, forward: 30.0 })
	apex_y =
		match shapes.get(1) {
			Ok(Triangle(t)) => t.first.y.to_f64()
			_ => crash "a tree's second shape is its top tier"
		}
	shapes.len() == 9 and apex_y == 464.0
}

expect [0.0, 59.9].all(|metres| trunk_finish_of(metres) == Shaded)
expect [60.0, 60.1].all(|metres| trunk_finish_of(metres) == Flat)
