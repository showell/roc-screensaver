## Lantern is a kind of lamp by the road: the colour its globe glows, and how
## tall its post stands, from the ground to the top of the globe, which is
## where the bird perches. LampShapes draws it.
import lib.RgbColor

Lantern := [Amber, Rose, Mint].{

	## A rose lamp stands a little taller than an amber one, and a mint one a
	## little shorter, so the bird's hops rise and fall; heights chosen by eye.
	height_metres : Lantern -> F64
	height_metres = |lantern|
		match lantern {
			Amber => 6.0
			Rose => 6.8
			Mint => 5.4
		}

	## The colour the globe's light is at its brightest.
	glow_color : Lantern -> RgbColor
	glow_color = |lantern|
		match lantern {
			Amber => RgbColor.of(0xFFC46B)
			Rose => RgbColor.of(0xFF8FA3)
			Mint => RgbColor.of(0x9FF2CF)
		}

	is_eq : _
}

expect Lantern.Rose.height_metres() > Lantern.Amber.height_metres()
expect Lantern.Mint.height_metres() < Lantern.Amber.height_metres()
expect Lantern.Amber.glow_color() == RgbColor.of(0xFFC46B)
