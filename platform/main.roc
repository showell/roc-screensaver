## This is the screensaver's platform. An app gives it a boxed model, a
## step from one model to the next, and the frame each model looks like
## (Frame.roc); the host (host/) steps the model at the app's pace, reads
## each frame out of memory and paints it with its software rasterizer.
##
## The host holds the model as one boxed pointer. `roc_step` takes the
## host's reference and gives back the next model's. `roc_frame` keeps
## nothing, so the host adds a reference before the call and Roc's drop
## on the way out takes it away again. The host hands each frame back to
## `roc_release_frame`, and the last model to `roc_release_model`, so Roc,
## which knows their layouts, frees what they hold.
platform ""
	requires {
		[Model : model] for program : {
			init : {} -> Box(model),

			## The number is that of the frame the next model is drawn as, so
			## the app knows the time (that number over `fps`, in seconds)
			## without keeping a clock of its own. The keys are the keyboard
			## at this step as two bit sets in lib/Keys.roc's bits: `held`,
			## the keys down now, and `struck`, those that went down since the
			## last step. They are plain numbers, as the page's are, so a host
			## fills them from its own key events with no Roc value to build.
			step : Box(model), U64, { held : U32, struck : U32 } -> Box(model),
			frame : Box(model) -> Frame,
			size : { width : U32, height : U32 },
			fps : U32,
		}
	}
	exposes [Frame]
	packages {}
	provides {
		"roc_fps": fps_for_host,
		"roc_frame": frame_for_host,
		"roc_height": height_for_host,
		"roc_init": init_for_host,
		"roc_release_frame": release_frame_for_host,
		"roc_release_model": release_model_for_host,
		"roc_step": step_for_host,
		"roc_width": width_for_host,
	}
	targets: {
		x64musl: {
			inputs: [app],
			output: Archive,
		},
		x64win: {
			inputs: [app],
			output: Archive,
		},
	}

import Frame

init_for_host = program.init

step_for_host = program.step

frame_for_host = program.frame

release_frame_for_host : Frame -> {}
release_frame_for_host = |_frame| {}

release_model_for_host : Box(Model) -> {}
release_model_for_host = |_model| {}

width_for_host : {} -> U32
width_for_host = |{}| program.size.width

height_for_host : {} -> U32
height_for_host = |{}| program.size.height

fps_for_host : {} -> U32
fps_for_host = |{}| program.fps
