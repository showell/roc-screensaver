## CodePane is the Lanterns page with its code pane: the screensaver, and the
## module of its own code the pane beside it shows, which CodeCues times to the
## scene. The page asks after every step what the pane should do, and the
## answer is the module's code, coloured, when the step brought a new one in,
## or where to scroll the code it has. So a restart, a skip and the rewind bring
## in the module for the step they land on, as a step that reaches a cue does.
##
## The scroll is the Roc's too, in lines: each module holds at its top for a
## moment, then scrolls down at an even pace and shows its last line at the
## pane's foot on the step before the next module comes in. A pause holds the
## scroll with the scene, and R or → land it where that step has it.
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

	## The screensaver's model, the module the pane shows, how many lines of
	## code it has, and whether the last step brought that module in.
	Model : { lanterns : LanternsApp.Model, file : Str, lines : U64, news : CodePane.News }

	## Whether the pane's module is new since the page last asked: a step that
	## crosses a cue, a restart or a skip, or the first model.
	News : [NewModule, SameModule]

	## What the pane does after a step: show a new module, or scroll the one it
	## shows so that the line `ScrollTo` names is at its top. A module comes
	## with its file's name, its code as coloured HTML, the line to start at,
	## and how many lines the pane shows at once, which the page sizes its
	## lines to, so the scroll ends with the last line at the pane's foot.
	Code : [ModuleSource({ file : Str, html : Str, top_line : F32, pane_lines : U32 }), ScrollTo(F32)]

	## How many lines of code the pane shows at once.
	pane_lines : U32
	pane_lines = 32

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
		init: module_at({ lanterns: lanterns_app.init, file: "", lines: 0, news: SameModule }, lanterns_app.init),
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
	model_at_next_step = |model, input, seconds| module_at(model, lanterns_step(model.lanterns, input, seconds))

	## What the pane does after the step that made `model`.
	code : CodePane.Model -> CodePane.Code
	code = |model| {
		top_line = top_line_at({ steps: model.lanterns.scene.steps, lines: model.lines })
		match model.news {
			NewModule => ModuleSource({ file: model.file, html: SyntaxColor.html(SyntaxColor.roc, CodeCues.code_of(model.file)), top_line, pane_lines: CodePane.pane_lines })
			SameModule => ScrollTo(top_line)
		}
	}
}

## The model with the screensaver at `lanterns`, and the module its scene is at:
## news when it is not the one `model` shows, its lines counted once, then.
module_at : CodePane.Model, LanternsApp.Model -> CodePane.Model
module_at = |model, lanterns| {
	file = CodeCues.file_at(lanterns.scene.steps)
	if file == model.file {
		{ ..model, lanterns, news: SameModule }
	} else {
		{ lanterns, file, lines: line_count(CodeCues.code_of(file)), news: NewModule }
	}
}

## How many lines `code` has: each ends with a newline.
line_count : Str -> U64
line_count = |code| code.to_utf8().count_if(|byte| byte == '\n')

## How many steps a module holds at its top before it scrolls, at most: a
## quarter of its time when that is shorter.
hold_steps : U64
hold_steps = 20

## A scroll slower than a line in this many steps moves in whole lines. The
## page draws a line about 17 pixels tall at its least, so a slower scroll
## would creep under a pixel a step, and the browser would show the code sharp
## at each whole pixel and blurred between them: a flicker. A module a line or
## two longer than the pane scrolls so slowly (Bird.roc's 33 lines did).
crawl_steps_a_line : U64
crawl_steps_a_line = 16

## The line at the pane's top `steps` into the cycle, for a module of `lines`
## lines: the first through the hold, then on at an even pace to the line that
## puts its last at the pane's foot, reached on the step before the next
## module comes in. A module the pane holds whole never scrolls, and one that
## would crawl moves a whole line at a time, each where the even pace passes
## that line's middle.
top_line_at : { steps : U64, lines : U64 } -> F32
top_line_at = |{ steps, lines }| {
	showing = CodeCues.showing_at(steps)
	shown = CodePane.pane_lines.to_u64()
	room = if lines > shown {
		lines - shown
	} else {
		0
	}
	span = showing.until - showing.from
	hold = hold_steps.min(span // 4)
	into = steps - showing.from
	if room == 0 or into <= hold {
		0.0
	} else if into + 1 >= span {
		room.to_f32()
	} else {
		scrolling = span - hold - 1
		if room * crawl_steps_a_line < scrolling {
			((2 * room * (into - hold) + scrolling) // (2 * scrolling)).to_f32()
		} else {
			room.to_f32() * (into - hold).to_f32() / scrolling.to_f32()
		}
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

# The model `count` steps into the cycle with no key struck, from the first.
played : U64 -> CodePane.Model
played = |count| {
	var $model = CodePane.canvas_app.init
	for _step in 0..<count {
		$model = CodePane.model_at_next_step($model, Input.none, 0.0)
	}
	$model
}

# The first model brings in the first cue's module at its top, with its name
# and its lines counted, and a step within that cue only scrolls.
expect {
	first = CodePane.canvas_app.init
	stepped = CodePane.model_at_next_step(first, Input.none, 0.0)
	first.file == "main.roc" and first.lines == 12
		and CodePane.code(first) == ModuleSource({ file: "main.roc", html: SyntaxColor.html(SyntaxColor.roc, CodeCues.code_of("main.roc")), top_line: 0.0, pane_lines: 32 })
		and stepped.lanterns == lanterns_step(first.lanterns, Input.none, 0.0)
		and stepped.file == "main.roc" and CodePane.code(stepped) == ScrollTo(0.0)
}

# The step that reaches a cue brings its module in at its top, and the next
# only scrolls.
expect {
	model = played(50)
	after = CodePane.model_at_next_step(model, Input.none, 0.0)
	model.lanterns.scene.steps == 50 and model.file == "LanternsApp.roc" and model.news == NewModule
		and (
			match CodePane.code(model) {
				ModuleSource(arrival) => arrival.file == "LanternsApp.roc" and arrival.top_line == 0.0
				ScrollTo(_) => Bool.False
			}
		)
		and after.news == SameModule and CodePane.code(after) == ScrollTo(0.0)
}

# Every cued module holds at its top as it comes in, scrolls on at every step
# after its hold, never back, and shows its last line at the pane's foot on the
# step before the next module comes in, the last one before the rewind.
expect CodeCues.cues.all(
	|cue| {
		showing = CodeCues.showing_at(cue.step)
		lines = line_count(CodeCues.code_of(cue.file))
		end = if lines > 32 {
			(lines - 32).to_f32()
		} else {
			0.0
		}
		var $backward = 0
		var $last = 0.0
		for steps in showing.from..<showing.until {
			now = top_line_at({ steps, lines })
			$backward = if now < $last {
				$backward + 1
			} else {
				$backward
			}
			$last = now
		}
		top_line_at({ steps: showing.from, lines }) == 0.0
			and top_line_at({ steps: showing.until - 1, lines }) == end
			and $backward == 0
	},
)

# A long module is partway down halfway through its time: BannerPlane's.
expect {
	lines = line_count(CodeCues.code_of("BannerPlane.roc"))
	halfway = top_line_at({ steps: 512, lines })
	lines > 100 and halfway > 0.0 and halfway < (lines - 32).to_f32()
}

# The lines a module of `lines` lines has at the pane's top through the showing
# that starts at `from`, in turn, each once.
tops_through : { from : U64, lines : U64 } -> List(F32)
tops_through = |{ from, lines }| {
	showing = CodeCues.showing_at(from)
	var $tops = []
	for steps in showing.from..<showing.until {
		now = top_line_at({ steps, lines })
		$tops = if $tops.last() == Ok(now) {
			$tops
		} else {
			$tops.append(now)
		}
	}
	$tops
}

# A module a line or two longer than the pane moves a whole line at a time,
# never creeping between, in any module's time on screen: Bird.roc, a line
# longer, shows its first line at the top, then its second, and nothing else.
expect line_count(CodeCues.code_of("Bird.roc")) == 33 and tops_through({ from: 1020, lines: 33 }) == [0.0, 1.0]
expect CodeCues.cues.all(|cue| tops_through({ from: cue.step, lines: 33 }) == [0.0, 1.0] and tops_through({ from: cue.step, lines: 34 }) == [0.0, 1.0, 2.0])

# R brings main.roc back from mid-cycle at its top; Space holds the module and
# its scroll; a skip brings in the module of the step it lands on, scrolled as
# a ride that reached that step has it.
expect {
	mid = played(150)
	restarted = CodePane.model_at_next_step(mid, Input.none.with_key_pressed(KeyR), 0.0)
	paused = CodePane.model_at_next_step(mid, Input.none.with_key_pressed(KeySpace), 0.0)
	still = CodePane.model_at_next_step(paused, Input.none, 0.0)
	mid.file == "BirdFlight.roc"
		and restarted.file == "main.roc" and restarted.news == NewModule
		and paused.file == "BirdFlight.roc" and paused.news == SameModule
		and CodePane.code(still) == CodePane.code(paused) and CodePane.code(paused) == ScrollTo(top_line_at({ steps: 150, lines: mid.lines }))
}
expect {
	skipped = CodePane.model_at_next_step(played(180), Input.none.with_key_pressed(KeyRight), 0.0)
	ridden = played(246)
	skipped.lanterns.scene.steps == 246 and skipped.file == "Sunrise.roc" and skipped.news == NewModule
		and (
			match CodePane.code(skipped) {
				ModuleSource(arrival) => ScrollTo(arrival.top_line) == CodePane.code(ridden) and arrival.top_line > 0.0
				ScrollTo(_) => Bool.False
			}
		)
}

# Every bundled module's comments were taken out, as Roc's own lexer reads
# them: roc-syntax-color finds no comment in its code.
expect LanternsSources.modules.all(|bundled| !SyntaxColor.spans(SyntaxColor.roc, bundled.code).any(|span| span.class == Comment))
