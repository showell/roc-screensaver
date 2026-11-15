## NativeApp turns a CanvasApp into what the native platform asks for, as
## lib's WasmApp does for the page: the same app value runs both ways. Each
## step hands the app the host's keys as an Input.Snapshot, in lib/Keys.roc's
## bits as the page's are, so an app reads the same keys either way. The
## pointer is always `Mouse.none` here, since no native host passes one yet.
## Each frame's shapes become a Frame through FrameOfShapes.
import pf.Frame
import lib.CanvasApp
import lib.Input
import lib.Keys
import lib.Mouse
import FrameOfShapes

NativeApp :: [].{
	# Roc reads `canvas_app.frame_shapes(m)` as a method call, so each of the app's
	# functions is bound before it is used, under its own name.
	program : CanvasApp.CanvasApp(model) -> {
		init : {} -> Box(model),
		step : Box(model), U64, { held : U32, struck : U32 } -> Box(model),
		frame : Box(model) -> Frame,
		size : { width : U32, height : U32 },
		fps : U32,
	}
	program = |canvas_app| {
		seconds_a_step = CanvasApp.seconds_a_step(canvas_app)
		model_at_next_step = canvas_app.model_at_next_step
		frame_shapes = canvas_app.frame_shapes
		{
			init: |{}| Box.box(canvas_app.init),
			# The host steps once a frame, as the page's runner does, so the
			# app counts its own steps and the frame number is not needed.
			step: |boxed_model, _frame_number, keys| Box.box(model_at_next_step(Box.unbox(boxed_model), snapshot_of(keys), seconds_a_step)),
			frame: |boxed_model| FrameOfShapes.frame_of(frame_shapes(Box.unbox(boxed_model))),
			size: {
				width: canvas_app.size.width.to_u32_try() ?? crash "NativeApp.program: a width outside a U32's range",
				height: canvas_app.size.height.to_u32_try() ?? crash "NativeApp.program: a height outside a U32's range",
			},
			fps: canvas_app.frames_a_second,
		}
	}

	## A step's input from the host's keys, with no pointer. Input.of holds a
	## struck key down too, as the page's does, so a host may pass a key that
	## went down and up between two steps as struck alone.
	snapshot_of : { held : U32, struck : U32 } -> Input.Snapshot
	snapshot_of = |{ held, struck }| Input.of({ held, struck, mouse: Mouse.none })
}

# A struck key is pressed and down; a held one is down and not pressed; a key
# in neither set is neither, and no key is anything in no keys at all.
expect {
	space = Keys.bit(KeySpace)
	right = Keys.bit(KeyRight)
	snapshot = NativeApp.snapshot_of({ held: right, struck: space })
	snapshot.key_pressed(KeySpace)
		and snapshot.key_down(KeySpace)
		and snapshot.key_down(KeyRight)
		and !snapshot.key_pressed(KeyRight)
		and !snapshot.key_down(KeyR)
		and !snapshot.key_pressed(KeyR)
}
expect {
	snapshot = NativeApp.snapshot_of({ held: 0, struck: 0 })
	Keys.all_keys.all(|key| !snapshot.key_down(key) and !snapshot.key_pressed(key))
}
