## CodePane is the Lanterns page with its code pane: the screensaver, and the
## module of its own code the pane beside it shows, which CodeCues times to the
## scene. The page asks after every step what the pane should do, and the
## answer is the module's code, coloured, when the step brought a new one in,
## or word to keep the code it has. So a restart, a skip and the rewind bring in
## the module for the step they land on, as a step that reaches a cue does.
##
## Only the page reads it: the native build runs LanternsApp itself, so its
## frames are the page's.
import CodeCues
import LanternsApp
import LanternsSources
import SceneCycle
import lib.CanvasApp
import lib.Input
import lib.Shapes
import lib.Skin
import lib.WasmApp
import sc.SyntaxColor

CodePane :: [].{

	## The screensaver's model, the module the pane shows, and whether the last
	## step brought that module in.
	Model : { lanterns : LanternsApp.Model, file : Str, news : CodePane.News }

	## Whether the pane's module is new since the page last asked: a step that
	## crosses a cue, a restart or a skip, or the first model.
	News : [NewModule, SameModule]

	## What the pane does after a step: show a module's code, as coloured
	## HTML, or keep the code it shows.
	Code : [ModuleSource(Str), KeepCurrentCode]

	## The screensaver as the code pane's platform asks for it: the canvas
	## apps' functions over this model, dressed in `skin`, and the pane's code.
	program : Skin.Skin -> {
		init : {} -> Box(CodePane.Model),
		model_at_next_step : Box(CodePane.Model), U32, U32, U32, U32, F32, F32, F32 -> Box(CodePane.Model),
		frame_shapes : Box(CodePane.Model) -> List(Shapes.Shape),
		release : List(Shapes.Shape) -> {},
		sounds : Box(CodePane.Model) -> U32,
		tone_count : {} -> U32,
		tone_freq : U32 -> U32,
		tone_ms : U32 -> U32,
		width : {} -> U32,
		height : {} -> U32,
		fps : {} -> U32,
		dressing : {} -> Box(Skin.Dressing),
		code : Box(CodePane.Model) -> Box(CodePane.Code),
	}
	program = |skin| {
		page = WasmApp.program_with_skin(CodePane.canvas_app, skin)
		{
			init: page.init,
			model_at_next_step: page.model_at_next_step,
			frame_shapes: page.frame_shapes,
			release: page.release,
			sounds: page.sounds,
			tone_count: page.tone_count,
			tone_freq: page.tone_freq,
			tone_ms: page.tone_ms,
			width: page.width,
			height: page.height,
			fps: page.fps,
			dressing: page.dressing,
			code: |boxed_model| Box.box(CodePane.code(Box.unbox(boxed_model))),
		}
	}

	## LanternsApp over this model: the same size, pace, keys and frames, with
	## the pane's module kept beside them.
	canvas_app : CanvasApp.CanvasApp(CodePane.Model)
	canvas_app = {
		size: lanterns_app.size,
		frames_a_second: lanterns_app.frames_a_second,
		init: { lanterns: lanterns_app.init, file: CodeCues.file_at(lanterns_app.init.scene.steps), news: NewModule },
		model_at_next_step: CodePane.model_at_next_step,
		frame_shapes: |model| lanterns_frame_shapes(model.lanterns),
		sounds: |model| lanterns_sounds(model.lanterns),
		tones: lanterns_app.tones,
		title: lanterns_app.title,
		controls: lanterns_app.controls,
	}

	## The model after one step: the screensaver's step, then the module its
	## new scene is at.
	model_at_next_step : CodePane.Model, Input.Snapshot, F32 -> CodePane.Model
	model_at_next_step = |model, input, seconds| {
		lanterns = lanterns_step(model.lanterns, input, seconds)
		file = CodeCues.file_at(lanterns.scene.steps)
		news = if file == model.file {
			SameModule
		} else {
			NewModule
		}
		{ lanterns, file, news }
	}

	## What the pane does after the step that made `model`.
	code : CodePane.Model -> CodePane.Code
	code = |model|
		match model.news {
			NewModule => ModuleSource(colored_module(model.file))
			SameModule => KeepCurrentCode
		}
}

lanterns_app : CanvasApp.CanvasApp(LanternsApp.Model)
lanterns_app = LanternsApp.canvas_app

# Roc reads `lanterns_app.frame_shapes(m)` as a method call, so each function is
# bound under its own name before it is called.
lanterns_step : LanternsApp.Model, Input.Snapshot, F32 -> LanternsApp.Model
lanterns_step = lanterns_app.model_at_next_step

lanterns_frame_shapes : LanternsApp.Model -> List(Shapes.Shape)
lanterns_frame_shapes = lanterns_app.frame_shapes

lanterns_sounds : LanternsApp.Model -> U32
lanterns_sounds = lanterns_app.sounds

## The module `file`'s code under a comment naming its file, coloured and
## escaped as HTML by roc-syntax-color.
colored_module : Str -> Str
colored_module = |file| SyntaxColor.html(SyntaxColor.roc, "# screensavers/lanterns/${file}\n\n${CodeCues.code_of(file)}")

# The first model brings in the first cue's module, and a step within that
# cue keeps it.
expect {
	first = CodePane.canvas_app.init
	stepped = CodePane.model_at_next_step(first, Input.none, 0.0)
	first.file == "main.roc" and CodePane.code(first) == ModuleSource(colored_module("main.roc"))
		and stepped.lanterns == lanterns_step(first.lanterns, Input.none, 0.0)
		and stepped.file == "main.roc" and CodePane.code(stepped) == KeepCurrentCode
}

# The step that reaches a cue brings its module in, and the next keeps it.
expect {
	var $model = CodePane.canvas_app.init
	for _step in 0..<50 {
		$model = CodePane.model_at_next_step($model, Input.none, 0.0)
	}
	after = CodePane.model_at_next_step($model, Input.none, 0.0)
	$model.lanterns.scene.steps == 50 and $model.file == "LanternsApp.roc" and $model.news == NewModule
		and after.news == SameModule and CodePane.code(after) == KeepCurrentCode
}

# R brings main.roc back from mid-cycle; a skip brings in the module of the
# step it lands on; a pause keeps the module.
expect {
	mid = { lanterns: { scene: SceneCycle.scene_after(SceneCycle.first_scene, 106), play: Playing }, file: "BirdFlight.roc", news: SameModule }
	restarted = CodePane.model_at_next_step(mid, Input.none.with_key_pressed(KeyR), 0.0)
	paused = CodePane.model_at_next_step(mid, Input.none.with_key_pressed(KeySpace), 0.0)
	restarted.file == "main.roc" and restarted.news == NewModule
		and paused.file == "BirdFlight.roc" and paused.news == SameModule
}
expect {
	var $model = CodePane.canvas_app.init
	for _step in 0..<180 {
		$model = CodePane.model_at_next_step($model, Input.none, 0.0)
	}
	skipped = CodePane.model_at_next_step($model, Input.none.with_key_pressed(KeyRight), 0.0)
	$model.file == "BirdFlight.roc" and skipped.lanterns.scene.steps == 246 and skipped.file == "Sunrise.roc" and skipped.news == NewModule
}

# The pane's code is the module's, coloured: its file named in a comment, and
# its text, the tags taken out, the module's code escaped.
expect {
	html = colored_module("main.roc")
	html.starts_with("<span class=\"syn-comment\"># screensavers/lanterns/main.roc</span>") and html.contains("NativeApp")
}

# Every bundled module's comments were taken out, as Roc's own lexer reads
# them: roc-syntax-color finds no comment in its code.
expect LanternsSources.modules.all(|bundled| !SyntaxColor.spans(SyntaxColor.roc, bundled.code).any(|span| span.class == Comment))
