# Lanterns

A sunrise made for Roc's 0.1.0 launch. The Roc bird hops from lamp to lamp
down an endless road as the sun comes up, crossing it each way in turn, each
hop one lamp further on. The bird and its flight are adapted from Safari's,
in roc-apps, and drawn at 4.2 m, nearly twice Safari's size. The camera moves
down the road at one constant speed, the bird's pace over a leg, so the bird
draws ahead through each flight and the camera catches up through each perch.

## The cycle

The scene runs in a cycle (`Sunrise.roc`, and the counts in
`SceneCycle.roc`) of twenty crossings and a closing perch: 20 legs of 66
steps and 30 more, 1350 steps, 45 seconds at 30 steps a second.

- **The sun** starts hidden behind the far range's ridge, in the notch at its
  lowest point. It first peeks over the ridge at step 199, just after the
  third crossing, and is clear of it at step 765.
- **The light:** the sky, the range, the hills, the grass and the road
  brighten at an even pace to the last step. The lamps' halos and pools,
  strongest at dawn, ease off but stay faintly lit.
- **The rewind:** then the whole model starts again from its first frame, so
  every cycle is the same.

## The plane

A small red high-wing plane, about 60 pixels long, tows a cream banner that
reads "Welcome to Roc!" (`BannerPlane.roc`). Its nose comes in from the left
edge at step 400 (about 13 s), and it crosses at 1.75 pixels a step. The
banner's tail leaves the right edge at step 1174 (about 39 s), so the sky is
empty again for the last few seconds. Where it is depends only on the
cycle's step, so R, the rewind and → move it with everything else. An
expect holds it clear of the sun's disc, and at least 20 pixels above the
bird, at every step it is in view. The letters are strokes from
`lib/Font.roc`, since the native painter has no `Text`.

## The fly-by

Once the banner is gone, five small jets in a V, deep blue with yellow trim
and no markings, fly over the camera from behind it and streak away up the
sky to the right (`JetFlyBy.roc`). They come in over the top edge at step
1276 (about 42.5 s), large and close, fly 10 m a step on a straight climbing
path, and shrink to specks as they near a point in the sky right of the sun
and well above the ridge, trailing pale smoke. They fade over the pass's last
14 steps and are gone at step 1340, ten steps before the rewind. Each corner
is seen through `RoadCamera`'s own projection, from a path laid out where the
camera stands; each jet is drawn level, belly to the camera, since in the
plane of its climb it would be seen edge on. The jets are sorted among the
lamps and the bird by their distance, and an expect holds all of their
drawing above the ridge's highest peak and at least 20 pixels above the
bird's at every step of the pass.

## The keys

The app reads its keys from its step's `Input.Snapshot`, so they work the
same on the page and in the Windows window. Each acts on the step a key is
struck, never while it is held.

- **Space** pauses, holding everything still, and a second Space resumes.
- **R** starts again at dawn and plays, even from a pause.
- **→** skips ahead one crossing, 66 steps at once, wrapping past the
  cycle's end as the cycle does. A paused scene skips and stays paused.

With no key struck it plays on by itself. The real screensaver (`/s`) ends on
any key, so it never sees them.

## The page

`web.roc` holds Steve's skin: the warming-up pill and the keyboard help on,
and the links Home (https://roc.lynrummy.com) and Code (this repo).
`?step=N` shows the frame after N steps and stops there, to be laid beside
`zig build png -- out/x N`'s.
