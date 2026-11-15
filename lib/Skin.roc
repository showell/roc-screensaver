## Skin is the dressing a web page puts around an app: whether the page shows
## its warming-up indicator over the first frame, whether it shows the app's
## keyboard help under the canvas, and the links it shows beside it. An app's
## web root chooses one and hands it to `WasmApp.program_with_skin`, so a skin
## never changes the app, and the native build, which has no web root, never
## sees it.
##
## The keyboard help itself comes from the app (`CanvasApp.controls`); a skin
## only says whether to show it.
import CanvasApp

Skin :: [].{
	Skin : {
		show_loading_indicator : Bool,
		show_keyboard_help : Bool,
		links : List(Skin.Link),
	}

	## A link the page shows: the words on it and where it goes.
	Link : { label : Str, url : Str }

	## What the page reads from the wasm once, at the start: the skin, and the
	## app's keyboard help as one line, made in Roc from its controls.
	Dressing : { skin : Skin.Skin, keyboard_help : Str }

	## The skin that dresses nothing: no indicator, no help, no links.
	bare : Skin.Skin
	bare = { show_loading_indicator: Bool.False, show_keyboard_help: Bool.False, links: [] }

	dressing_of : CanvasApp.CanvasApp(model), Skin.Skin -> Skin.Dressing
	dressing_of = |canvas_app, skin| { skin, keyboard_help: CanvasApp.help_line(canvas_app.controls) }
}

expect Skin.bare.links == [] and !Skin.bare.show_loading_indicator and !Skin.bare.show_keyboard_help
expect {
	canvas_app = {
		size: { width: 1.0, height: 1.0 },
		frames_a_second: 30,
		init: {},
		model_at_next_step: |model, _input, _seconds| model,
		frame_shapes: |_model| [],
		sounds: |_model| 0,
		tones: [],
		title: "test",
		controls: [{ keys: "Space", does: "pauses" }, { keys: "→", does: "skips" }],
	}
	skin = { show_loading_indicator: Bool.True, show_keyboard_help: Bool.False, links: [{ label: "Home", url: "https://example.org" }] }
	dressing = Skin.dressing_of(canvas_app, skin)
	dressing.keyboard_help == "Space pauses · → skips" and dressing.skin == skin
}
