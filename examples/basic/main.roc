# The basic example: a sky with a sun going down, hills, a road, and a few
# shapes that move a little each step, so that no two frames are alike. It
# fills one shape of each kind the platform paints.
#
# It is the host tests' fixture (host/screensaver_test.zig), not a
# screensaver: the tests know its every shape and word by heart, which they
# could not of a scene built through the adapter, and it reaches the raster's
# own sky and sun, which no canvas app does.
app [Model, program] { pf: platform "../../platform/main.roc" }

import pf.Frame

## The seconds since the first frame.
Model : { seconds : F32 }

fps : U32
fps = 30

program = {
	init: |{}| Box.box({ seconds: 0.0 }),
	step: |_model, frame_number| Box.box({ seconds: frame_number.to_f32() / fps.to_f32() }),
	frame: |model| frame_at(Box.unbox(model).seconds),
	size: { width: 480, height: 300 },
	fps,
}

frame_at : F32 -> Frame
frame_at = |seconds| {
	background: {
		sky_top: 0x2a3f7a,
		sky_horizon: 0xf2a65a,
		roll: 0.03 * (seconds * 1.5).sin(),
		sun: Shown({ x: 330.0, y: 90.0 + 12.0 * seconds, scale: 0.4 }),
	},
	shapes: [
		hills,
		road,
		panel(seconds),
		blob(seconds),
		lamp(seconds),
		beacon(seconds),
	],
}

hills : Frame.Shape
hills = Polygon({
	points: [
		{ x: 0.0, y: 150.0 },
		{ x: 90.0, y: 95.0 },
		{ x: 170.0, y: 135.0 },
		{ x: 260.0, y: 80.0 },
		{ x: 380.0, y: 140.0 },
		{ x: 480.0, y: 110.0 },
		{ x: 480.0, y: 151.0 },
		{ x: 0.0, y: 151.0 },
	],
	fill: Round({ color: 0x5c6b4a, strength: 0.8 }),
})

road : Frame.Shape
road = Polygon({
	points: [
		{ x: 225.0, y: 150.0 },
		{ x: 255.0, y: 150.0 },
		{ x: 400.0, y: 300.0 },
		{ x: 80.0, y: 300.0 },
	],
	fill: Solid(0x55504a),
})

## A box whose shading slides along it as time goes on.
panel : F32 -> Frame.Shape
panel = |seconds| {
	left = 40.0 + 20.0 * seconds
	Polygon({
		points: [
			{ x: left, y: 190.0 },
			{ x: left + 60.0, y: 190.0 },
			{ x: left + 60.0, y: 250.0 },
			{ x: left, y: 250.0 },
		],
		fill: Linear({
			from: { x: left, y: 190.0 },
			to: { x: left + 60.0, y: 250.0 },
			start: { color: 0xffd04a3a, at: 0.1 },
			end: { color: 0xff3a1e6e, at: 0.9 },
		}),
	})
}

## A rounded body that bobs up and down.
blob : F32 -> Frame.Shape
blob = |seconds| {
	cx = 360.0
	cy = 220.0 + 8.0 * (seconds * 2.0).sin()
	Polygon({
		points: [
			{ x: cx - 40.0, y: cy },
			{ x: cx - 28.0, y: cy - 22.0 },
			{ x: cx, y: cy - 30.0 },
			{ x: cx + 28.0, y: cy - 22.0 },
			{ x: cx + 40.0, y: cy },
			{ x: cx + 28.0, y: cy + 22.0 },
			{ x: cx, y: cy + 30.0 },
			{ x: cx - 28.0, y: cy + 22.0 },
		],
		fill: Elliptical({
			center: { x: cx - 10.0, y: cy - 10.0 },
			u: { x: 50.0, y: 0.0 },
			v: { x: 0.0, y: 40.0 },
			start: { color: 0xfff0e0c0, at: 0.0 },
			end: { color: 0xff7a5030, at: 1.0 },
		}),
	})
}

## A glow that drifts down the road.
lamp : F32 -> Frame.Shape
lamp = |seconds| {
	cx = 240.0
	cy = 200.0 + 10.0 * seconds
	Polygon({
		points: [
			{ x: cx - 30.0, y: cy - 30.0 },
			{ x: cx + 30.0, y: cy - 30.0 },
			{ x: cx + 30.0, y: cy + 30.0 },
			{ x: cx - 30.0, y: cy + 30.0 },
		],
		fill: Radial({
			center: { x: cx, y: cy },
			radius: 30.0,
			inner: 0xe0fff6b0,
			outer: 0x00fff6b0,
		}),
	})
}

## A light on the far hill that pulses.
beacon : F32 -> Frame.Shape
beacon = |seconds| Disc({
	center: { x: 260.0, y: 76.0 },
	radius: 5.0,
	color: 0xff3030,
	alpha: 0.55 + 0.45 * (seconds * 4.0).sin(),
})
