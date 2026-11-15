# The lanterns screensaver, as a page: the wasm module a browser runs, dressed
# in Steve's skin. The skin is chosen here, in the web root alone, so the
# native build never sees it.
app [Model, program] { lib: "../../lib/main.roc", pf: platform "../../web/platform/main.roc" }

import lib.Skin
import lib.WasmApp
import LanternsApp

Model : LanternsApp.Model

skin : Skin.Skin
skin = {
	show_loading_indicator: Bool.True,
	show_keyboard_help: Bool.True,
	links: [
		{ label: "Home", url: "https://roc.lynrummy.com" },
		{ label: "Code", url: "https://github.com/showell/roc-screensaver" },
	],
}

program = WasmApp.program_with_skin(LanternsApp.canvas_app, skin)
