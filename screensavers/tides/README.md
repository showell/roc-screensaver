# Tides

Six bands of water roll under a sky that goes from dawn to day, to dusk, to
night and back to dawn. Each band's top edge is a sum of two slow swells
drifting left, and the nearer a band is, the lower it lies and the taller,
longer and faster its swells are, so the water reads as rows of waves going
off to the horizon. The bands run from a pale one at the horizon to a deep one
at the bottom of the screen, and take their colours from the sky's moment.

## The cycle

The cycle is 3600 steps, two minutes at 30 steps a second (`TidesApp.roc`),
in four even quarters, dawn, day, dusk and night, each blending into the next
(`Daylight.roc`). The sun rises out of the sea at dawn, crosses the sky and
sinks back into it in the middle of dusk; the moon crosses the night and sets
just before dawn. Every swell makes a whole number of turns a cycle, so when
the cycle starts again the water and the sky are just as they began, and
every run plays the same frames.

## Drawing it natively

Every shape is one the native painter draws: the sky is a rectangle with a
`Linear` fill, each band a flat `Polygon` of 123 corners (one every 8 pixels
along its top), the sun and the moon flat discs, and the sun's glow the one
`Radial` fill. An expect holds each frame to that.

## The keys

- **Space** pauses, holding everything still, and a second Space resumes.
- **R** starts again at dawn and plays, even from a pause.

With no key struck it plays on by itself.

## The page

`web.roc` holds Steve's skin, the same as lanterns': the warming-up pill and
the keyboard help on, and the links Home (https://roc.lynrummy.com) and Code
(this repo). `?step=N` shows the frame after N steps and stops there, to be
laid beside `zig build png -Dapp=screensavers/tides/main.roc -- out/x N`'s.
