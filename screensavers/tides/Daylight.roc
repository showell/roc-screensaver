## Daylight is the colour of the tides' sky and water at each moment of the
## cycle. The cycle is four quarters, dawn, day, dusk and night, and each
## quarter blends evenly into the next, night back into dawn, so the colours
## never jump, not even where the cycle starts again.
import lib.ColorShade
import lib.Fraction
import lib.RgbColor

Daylight :: [].{

	## The colours of one moment: the sky at its top and at the horizon, and
	## the water from its palest band, farthest off, to its deepest, nearest.
	Light : {
		sky_top : RgbColor,
		sky_horizon : RgbColor,
		water_pale : RgbColor,
		water_deep : RgbColor,
	}

	## The light `day` of the way through the cycle, which starts at dawn.
	light_at : Fraction -> Daylight.Light
	light_at = |day| {
		quarter = day.to_f64() * 4.0
		index = quarter.floor_to_u64_try() ?? crash "Daylight.light_at: a fraction of the cycle is a whole number of quarters and a part"
		within = Fraction.clamp(quarter - index.to_f64())
		{ from, to } =
			match index {
				# A whole cycle is dawn again.
				0 | 4 => { from: dawn, to: noon }
				1 => { from: noon, to: dusk }
				2 => { from: dusk, to: night }
				3 => { from: night, to: dawn }
				_ => crash "Daylight.light_at: a fraction of the cycle is at most four quarters"
			}
		between = |color_of| ColorShade.color_between({ from: color_of(from), to: color_of(to), fraction: within })
		{
			sky_top: between(|light| light.sky_top),
			sky_horizon: between(|light| light.sky_horizon),
			water_pale: between(|light| light.water_pale),
			water_deep: between(|light| light.water_deep),
		}
	}
}

## The four keys of the cycle, chosen by eye.
dawn : Daylight.Light
dawn = {
	sky_top: RgbColor.of(0x3B4A7A),
	sky_horizon: RgbColor.of(0xF2A07B),
	water_pale: RgbColor.of(0xC9A9A6),
	water_deep: RgbColor.of(0x1E3550),
}

noon : Daylight.Light
noon = {
	sky_top: RgbColor.of(0x3A86D0),
	sky_horizon: RgbColor.of(0xBFE3F5),
	water_pale: RgbColor.of(0x9FD8E0),
	water_deep: RgbColor.of(0x0D4F78),
}

dusk : Daylight.Light
dusk = {
	sky_top: RgbColor.of(0x4A3470),
	sky_horizon: RgbColor.of(0xF07A4A),
	water_pale: RgbColor.of(0xD08A70),
	water_deep: RgbColor.of(0x2A2450),
}

night : Daylight.Light
night = {
	sky_top: RgbColor.of(0x060A1E),
	sky_horizon: RgbColor.of(0x1A2448),
	water_pale: RgbColor.of(0x2C4466),
	water_deep: RgbColor.of(0x050C1C),
}

# Each quarter starts on its own key, and the whole cycle ends on dawn.
expect Daylight.light_at(Fraction.zero) == dawn
expect Daylight.light_at(Fraction.of(0.25)) == noon
expect Daylight.light_at(Fraction.of(0.5)) == dusk
expect Daylight.light_at(Fraction.of(0.75)) == night
expect Daylight.light_at(Fraction.whole) == dawn

# Halfway through a quarter is halfway between its two keys.
expect Daylight.light_at(Fraction.of(0.125)).sky_top == ColorShade.color_between({ from: dawn.sky_top, to: noon.sky_top, fraction: Fraction.of(0.5) })
