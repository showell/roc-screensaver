# The Lanterns page's platform: the canvas apps' platform (web/platform/main.roc)
# with one function more, `code`, which says what the page's code pane shows
# after each step. Its host (host.zig) is the canvas apps' host with one export
# more, computeCode. Only lanterns' web.roc names it, so Tides and Bubbles
# build as they did.
#
# Fourteen functions: the canvas apps' twelve, `code`, and the platform's own
# `release_code`, which takes back the last answer when the host asks for the
# next. `code` answers a box, so the host holds one pointer the page's glue
# reads, as it reads the dressing.
platform ""
	requires {
		[Model : model] for program : {
			init : {} -> Box(model),
			model_at_next_step : Box(model), U32, U32, U32, U32, F32, F32, F32 -> Box(model),
			frame_shapes : Box(model) -> List(Shapes.Shape),
			release : List(Shapes.Shape) -> {},
			sounds : Box(model) -> U32,
			tone_count : {} -> U32,
			tone_freq : U32 -> U32,
			tone_ms : U32 -> U32,
			width : {} -> U32,
			height : {} -> U32,
			fps : {} -> U32,
			dressing : {} -> Box(Skin.Dressing),
			code : Box(model) -> Box([ModuleSource(Str), KeepCurrentCode]),
		}
	}
	exposes []
	packages { lib: "../../lib/main.roc" }
	provides {
		"roc_advance": advance_for_host,
		"roc_code": code_for_host,
		"roc_dressing": dressing_for_host,
		"roc_fps": fps_for_host,
		"roc_frame": frame_for_host,
		"roc_height": height_for_host,
		"roc_init": init_for_host,
		"roc_release": release_for_host,
		"roc_release_code": release_code_for_host,
		"roc_sounds": sounds_for_host,
		"roc_tone_count": tone_count_for_host,
		"roc_tone_freq": tone_freq_for_host,
		"roc_tone_ms": tone_ms_for_host,
		"roc_width": width_for_host,
	}
	targets: {
		inputs_dir: "targets/",
		wasm32: {
			inputs: ["host.wasm", app],
			exports: ["computeFrame", "advance", "sounds", "toneCount", "toneFreq", "toneMs", "width", "height", "fps", "computeDressing", "computeCode"],
		},
	}

import lib.Shapes
import lib.Skin

init_for_host = program.init

advance_for_host = program.model_at_next_step

frame_for_host = program.frame_shapes

release_for_host = program.release

sounds_for_host = program.sounds

tone_count_for_host = program.tone_count

tone_freq_for_host = program.tone_freq

tone_ms_for_host = program.tone_ms

width_for_host = program.width

height_for_host = program.height

fps_for_host = program.fps

dressing_for_host = program.dressing

code_for_host = program.code

# The host hands the last answer back and Roc drops it, since dropping a
# string is Roc's to do, as `release` is for a frame.
release_code_for_host : Box([ModuleSource(Str), KeepCurrentCode]) -> {}
release_code_for_host = |_code| {}
