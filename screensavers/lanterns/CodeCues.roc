## CodeCues is the script of the page's code pane: which Lanterns module the
## pane shows at each step of the cycle. A cue is the step a module comes in at,
## each timed to a beat of the scene: the sunrise's module as the sun first
## peeks over the mountain, the banner plane's as it flies in, the jets' as they
## fly. A module stays until the next cue's step, and the first cue's comes in
## again with the rewind. Not every module has a cue.
##
## Only the page reads it: the native build never imports it.
import BannerPlane
import BirdFlight
import JetFlyBy
import LanternsSources
import SceneCycle

CodeCues :: [].{

	## One line of the script: from `step` into the cycle, the pane shows `file`,
	## on a dark page or a light one.
	Cue : { step : U64, file : Str, page : CodeCues.Page }

	## The pane's page: dark through the night and the sunrise, light once day
	## has come, from the cue as the lamps fade on to the rewind's dawn.
	Page : [Dark, Light]

	## The script, a cue a line, in the cycle's order. Each line says its beat.
	cues : List(CodeCues.Cue)
	cues = [
		# Dawn: the app's root, as the cycle starts.
		{ step: 0, file: "main.roc", page: Dark },
		# The bird is on its first crossing: the app, its model, keys and frame.
		{ step: 50, file: "LanternsApp.roc", page: Dark },
		# The bird takes off on its second crossing.
		{ step: 96, file: "BirdFlight.roc", page: Dark },
		# The sun first peeks over the mountain.
		{ step: 199, file: "Sunrise.roc", page: Dark },
		# The bird takes off on its fifth crossing, between the lamps.
		{ step: 294, file: "RoadLamps.roc", page: Dark },
		# The banner plane flies in from the left.
		{ step: 400, file: "BannerPlane.roc", page: Dark },
		# The bird takes off on its tenth crossing, the camera following.
		{ step: 624, file: "RoadCamera.roc", page: Dark },
		# The sun climbs clear of the mountain.
		{ step: 765, file: "BackdropShapes.roc", page: Dark },
		# The bird takes off on its fourteenth crossing, the lamps fading: day.
		{ step: 888, file: "LampShapes.roc", page: Light },
		# The bird takes off on its sixteenth crossing.
		{ step: 1020, file: "Bird.roc", page: Light },
		# The banner is gone, and the cycle nears its end.
		{ step: 1174, file: "SceneCycle.roc", page: Light },
		# The jets fly over.
		{ step: 1276, file: "JetFlyBy.roc", page: Light },
	]

	## The module the pane shows `steps` into the cycle: the last cue's at or
	## before it.
	file_at : U64 -> Str
	file_at = |steps| CodeCues.showing_at(steps).file

	## The module the pane shows `steps` into the cycle, the page it is on, the
	## step it came in at, and the step the next one comes in at: the next
	## cue's, or the rewind's for the last.
	showing_at : U64 -> { file : Str, page : CodeCues.Page, from : U64, until : U64 }
	showing_at = |steps| {
		cue =
			match CodeCues.cues.find_last(|each| each.step <= steps) {
				Ok(found) => found
				Err(NotFound) => crash "CodeCues.showing_at: no cue at step 0, so step ${steps.to_str()} has no module"
			}
		until =
			match CodeCues.cues.find_first(|each| each.step > steps) {
				Ok(next) => next.step
				Err(NotFound) => SceneCycle.cycle_steps
			}
		{ file: cue.file, page: cue.page, from: cue.step, until }
	}

	## The code of the Lanterns module `file`, its comments taken out.
	code_of : Str -> Str
	code_of = |file|
		match LanternsSources.modules.find_first(|bundled| bundled.file == file) {
			Ok(bundled) => bundled.code
			Err(NotFound) => crash "CodeCues.code_of: ${file} is not in LanternsSources; run tools/bundle_lanterns_sources.shale"
		}
}

## The step the bird takes off on crossing `crossing`, counted from 1: its
## leg's perch is over.
takeoff_step : U64 -> U64
takeoff_step = |crossing| (crossing - 1) * SceneCycle.leg_steps + SceneCycle.leg_steps - BirdFlight.frame_count

# The script starts at the cycle's first step, runs in order, a step apart at
# least, and ends before the rewind.
expect {
	var $before = 0
	var $out_of_order = 0
	for cue in CodeCues.cues.drop_first(1) {
		$out_of_order =
			if cue.step > $before {
				$out_of_order
			} else {
				$out_of_order + 1
			}
		$before = cue.step
	}
	CodeCues.cues.first().map_ok(|cue| cue.step) == Ok(0) and $out_of_order == 0 and $before < SceneCycle.cycle_steps
}

# Every cue's module is bundled, and none is cued twice.
expect CodeCues.cues.all(|cue| LanternsSources.modules.any(|bundled| bundled.file == cue.file))
expect CodeCues.cues.all(|cue| CodeCues.cues.keep_if(|other| other.file == cue.file).len() == 1)

# The beats. The bird's cues fall on its take-offs: the step its flight starts.
expect [(96, 2), (294, 5), (624, 10), (888, 14), (1020, 16)].all(|(step, crossing)| takeoff_step(crossing) == step and SceneCycle.flight_stage(step % SceneCycle.leg_steps) == Playing(0))
# Sunrise's expects pin the sun hidden at step 198, touching the ridge at 199
# and clear of it at 765.
expect CodeCues.file_at(199) == "Sunrise.roc" and CodeCues.file_at(765) == "BackdropShapes.roc"
# The plane is still to come at step 399, in view at 400 and gone at 1174.
expect BannerPlane.flight_at(399) == Coming and BannerPlane.flight_at(400) != Coming and CodeCues.file_at(400) == "BannerPlane.roc"
expect BannerPlane.flight_at(1173) != Gone and BannerPlane.flight_at(1174) == Gone and CodeCues.file_at(1174) == "SceneCycle.roc"
# The jets' module comes in with the jets.
expect CodeCues.file_at(JetFlyBy.enters_step) == "JetFlyBy.roc" and CodeCues.file_at(JetFlyBy.enters_step - 1) == "SceneCycle.roc"

# A module stays until the next cue.
expect CodeCues.file_at(0) == "main.roc" and CodeCues.file_at(49) == "main.roc" and CodeCues.file_at(50) == "LanternsApp.roc"
expect CodeCues.file_at(SceneCycle.cycle_steps - 1) == "JetFlyBy.roc"
expect CodeCues.showing_at(60) == { file: "LanternsApp.roc", page: Dark, from: 50, until: 96 }
expect CodeCues.showing_at(1300) == { file: "JetFlyBy.roc", page: Light, from: 1276, until: SceneCycle.cycle_steps }

# The page turns light with LampShapes.roc, as the lamps fade, stays light to
# the rewind, and is dark again at dawn.
expect CodeCues.cues.keep_if(|cue| cue.page == Light).map(|cue| cue.file) == ["LampShapes.roc", "Bird.roc", "SceneCycle.roc", "JetFlyBy.roc"]
expect CodeCues.showing_at(887).page == Dark and CodeCues.showing_at(888).page == Light and CodeCues.showing_at(SceneCycle.cycle_steps - 1).page == Light and CodeCues.showing_at(0).page == Dark

# A bundled module's code is its own, comments and all taken out.
expect CodeCues.code_of("main.roc").contains("program = NativeApp.program(LanternsApp.canvas_app)")
expect !CodeCues.code_of("main.roc").contains("#")
