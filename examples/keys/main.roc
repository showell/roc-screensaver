# The keys example: a canvas app, run through NativeApp as the screensavers
# are, whose model counts keys, so host/keys_test.zig can see a key the host
# passes reach the app's step under lib/Keys.roc's names.
#
# Its frame tells the counts by its shapes: a first disc whose radius is one
# more than the steps the right arrow was held at, then one disc more for each
# time Space was struck.
app [Model, program] {
	lib: "../../lib/main.roc",
	native: "../../native/main.roc",
	pf: platform "../../platform/main.roc",
}

import lib.Brush
import lib.CanvasApp
import lib.Input
import lib.Pixels
import lib.Point
import lib.RgbColor
import lib.Shapes
import native.NativeApp

Model : { spaces_struck : U64, steps_right_held : U64 }

program = NativeApp.program(canvas_app)

canvas_app : CanvasApp.CanvasApp(Model)
canvas_app = {
	size: { width: 64.0, height: 64.0 },
	frames_a_second: 30,
	init: { spaces_struck: 0, steps_right_held: 0 },
	model_at_next_step: CanvasApp.untimed_model_at_next_step(counted),
	frame_shapes,
	sounds: |_model| 0,
	tones: [],
	title: "keys",
}

## The model after one step: a struck Space counted once, however long it is
## held after, and the right arrow counted at every step it is down.
counted : Model, Input.Snapshot -> Model
counted = |model, input| {
	spaces_struck: model.spaces_struck + (if (input.key_pressed(KeySpace)) 1 else 0),
	steps_right_held: model.steps_right_held + (if (input.key_down(KeyRight)) 1 else 0),
}

frame_shapes : Model -> List(Shapes.Shape)
frame_shapes = |model| {
	first = disc(1.0 + model.steps_right_held.to_f64())
	[first].concat(List.repeat(disc(1.0), model.spaces_struck))
}

disc : F64 -> Shapes.Shape
disc = |radius| Disc({ center: Point.at(32.0, 32.0), radius: Pixels.of(radius), fill: Brush.flat(RgbColor.of(0xFFFFFF)) })
