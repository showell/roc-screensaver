# The lanterns screensaver, as a page: the wasm module a browser runs.
app [Model, program] { lib: "../../lib/main.roc", pf: platform "../../web/platform/main.roc" }

import lib.WasmApp
import LanternsApp

Model : LanternsApp.Model

program = WasmApp.program(LanternsApp.canvas_app)
