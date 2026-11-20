# The lanterns screensaver, as a page: the wasm module a browser runs, dressed
# in Steve's skin, with the code pane beside the scene on a wide screen. The
# skin and the pane are chosen here, in the web root alone, so the native build
# never sees them. The pane's platform is the canvas apps' with one function
# more (web/lanterns_platform/), and its code is coloured by roc-syntax-color,
# a checkout beside this repo's.
app [Model, program] {
	lib: "../../lib/main.roc",
	pf: platform "../../web/lanterns_platform/main.roc",
	sc: "../../../roc-syntax-color/package/main.roc",
}

import lib.Skin
import CodePane

Model : CodePane.Model

skin : Skin.Skin
skin = {
	show_loading_indicator: Bool.True,
	show_keyboard_help: Bool.True,
	links: [
		{ label: "Home", url: "https://roc.lynrummy.com" },
		{ label: "Code", url: "https://github.com/showell/roc-screensaver" },
	],
}

program = CodePane.program(skin)
