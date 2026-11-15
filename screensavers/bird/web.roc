# The bird screensaver, as a page: the wasm module a browser runs.
app [Model, program] { lib: "../../lib/main.roc", pf: platform "../../web/platform/main.roc" }

import lib.WasmApp
import BirdApp

Model : BirdApp.Model

program = WasmApp.program(BirdApp.canvas_app)
