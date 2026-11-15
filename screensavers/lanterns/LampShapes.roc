## A lamp on the screen: its halo of light, an iron post shaded round, a cap,
## and the glass globe under the cap, lit from inside. The bird perches on the
## cap, so the cap's top is the lamp's height.
import Lantern
import lib.Brush
import lib.ColorShade
import lib.Fraction
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes

LampShapes :: [].{

	## Where a lamp stands on the screen: its foot's middle, and how tall it
	## looks.
	Upright : { foot : Point, height_on_screen : Pixels }

	## The lamp standing at `upright`: its halo, post, cap and globe, in the
	## order they are painted. Its halo is strongest at dawn and fainter as
	## `day` nears 1, since a lamp shows less as the light comes up.
	lamp_shapes : LampShapes.Upright, { lantern : Lantern, day : Fraction } -> List(Shapes.Shape)
	lamp_shapes = |upright, { lantern, day }| {
		h = upright.height_on_screen.to_f64()
		x = upright.foot.x.to_f64()
		top = upright.foot.y.to_f64() - h
		globe_radius = h * globe_share
		cap_height = h * cap_share
		globe_y = top + cap_height + globe_radius
		glow = lantern.glow_color()
		halo = Shapes.halo(
			{ center: Point.at(x, globe_y), radius: Pixels.of(globe_radius * halo_reach) },
			Brush.with_alpha(glow, 0.48 - 0.2 * day.to_f64()),
		)
		post_half = (h * post_share / 2.0).max(0.5)
		post_left = Pixels.of(x - post_half)
		post_right = Pixels.of(x + post_half)
		post = Shapes.rectangle({
			top_left: { x: post_left, y: Pixels.of(globe_y) },
			width: post_right.minus(post_left),
			height: Pixels.of(upright.foot.y.to_f64() - globe_y),
			fill: Brush.width_shade({ min_x: post_left, max_x: post_right }, { color: iron_color, strength: Fraction.whole }),
		})
		cap_half = globe_radius * 1.25
		cap = Quad({
			first: Point.at(x - globe_radius * 0.35, top),
			second: Point.at(x + globe_radius * 0.35, top),
			third: Point.at(x + cap_half, top + cap_height),
			fourth: Point.at(x - cap_half, top + cap_height),
			fill: Brush.flat(iron_color),
		})
		globe = Disc({
			center: Point.at(x, globe_y),
			radius: Pixels.of(globe_radius),
			fill: globe_fill({ x, y: globe_y, radius: globe_radius }, glow),
		})
		[halo, post, cap, globe]
	}
}

## Shares of the lamp's height on the screen, chosen by eye.
globe_share : F64
globe_share = 0.065

cap_share : F64
cap_share = 0.04

post_share : F64
post_share = 0.03

## How far the halo reaches, in globe radii, chosen by eye.
halo_reach : F64
halo_reach = 5.5

iron_color : RgbColor
iron_color = RgbColor.of(0x2E3340)

## The globe lit from inside: nearly white a little above and left of its
## middle, where the flame shows, and the lantern's colour, deepened, at its
## rim.
globe_fill : { x : F64, y : F64, radius : F64 }, RgbColor -> Brush.Fill
globe_fill = |{ x, y, radius }, glow| {
	hot = ColorShade.color_between({ from: glow, to: RgbColor.of(0xFFFFFF), fraction: Fraction.of(0.75) })
	rim = ColorShade.shade_color(glow, Darkened(Fraction.of(0.3)))
	stops = {
		start_color: Brush.opaque_rgba(hot),
		end_color: Brush.opaque_rgba(rim),
		start_offset: 0.1,
		end_offset: 1.0,
	}
	look = {
		stops,
		center: Point.at(x - radius * 0.3, y - radius * 0.3),
		axis_u: Point.at(radius * 1.3, 0.0),
		axis_v: Point.at(0.0, radius * 1.3),
	}
	match Brush.elliptical_gradient(look) {
		Ok(fill) => fill
		# A globe too small to shade is a dot of its own colour.
		Err(TooThin) => Brush.flat(glow)
	}
}

# A lamp is four shapes, and its cap's top is the lamp's height above its foot.
expect {
	shapes = LampShapes.lamp_shapes({ foot: Point.at(480.0, 500.0), height_on_screen: Pixels.of(200.0) }, { lantern: Lantern.Amber, day: Fraction.zero })
	top_y =
		match shapes.get(2) {
			Ok(Quad(q)) => q.first.y.to_f64()
			_ => crash "a lamp's third shape is its cap"
		}
	shapes.len() == 4 and top_y == 300.0
}
