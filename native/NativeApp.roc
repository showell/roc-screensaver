## NativeApp turns a CanvasApp into what the native platform asks for, as
## lib's WasmApp does for the page: the same app value runs both ways. Each
## step passes no input, since a screensaver takes none, and each frame's
## shapes become a Frame through FrameOfShapes.
import pf.Frame
import lib.CanvasApp
import lib.Input
import FrameOfShapes

NativeApp :: [].{
	# Roc reads `canvas_app.frame_shapes(m)` as a method call, so each of the app's
	# functions is bound before it is used, under its own name.
	program : CanvasApp.CanvasApp(model) -> {
		init : {} -> Box(model),
		step : Box(model), U64 -> Box(model),
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
			step: |boxed_model, _frame_number| Box.box(model_at_next_step(Box.unbox(boxed_model), Input.none, seconds_a_step)),
			frame: |boxed_model| FrameOfShapes.frame_of(frame_shapes(Box.unbox(boxed_model))),
			size: {
				width: canvas_app.size.width.to_u32_try() ?? crash "NativeApp.program: a width outside a U32's range",
				height: canvas_app.size.height.to_u32_try() ?? crash "NativeApp.program: a height outside a U32's range",
			},
			fps: canvas_app.frames_a_second,
		}
	}
}
