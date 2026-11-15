## The Roc bird as a frame draws it: its drawing for a pose, which way that
## drawing faces, and how tall the bird stands. The Roc bird is roc-lang.org's
## logo. BirdFlight says where a bird is and how it looks, and BirdStills holds
## its drawings.
##
## This file is adapted from roc-apps (`canvas_apps/safari/Bird.roc`) on
## 2026-11-15, and it is allowed to drift from it. Safari's bird always flies
## left to right, so it is never mirrored; this one crosses both ways, so
## `pose_flip` mirrors the stills that face along the flight.
import BirdFlight
import BirdStills
import Still
import StillOnScreen

Bird :: [].{

	## How tall a bird stands in metres, chosen by eye: taller than Safari's
	## 2.2, so the bird is the biggest thing at its depth.
	height_metres : F64
	height_metres = 2.8

	## The drawing for a pose.
	pose_still : BirdFlight.BirdPose -> Still
	pose_still = |pose|
		match pose {
			Perched => BirdStills.perched_still
			Side(WingsUp) => BirdStills.side_wings_up_still
			Side(WingsDown) => BirdStills.side_wings_down_still
			Away(WingsUp) => BirdStills.away_wings_up_still
			Away(WingsDown) => BirdStills.away_wings_down_still
			Diving => BirdStills.diving_still
		}

	## Which way to draw `pose` on a flight with `heading`. An unmirrored
	## still's beak points toward +x, so a bird crossing leftward is mirrored.
	## A bird seen from behind keeps its left wing on the left whichever way it
	## crosses, so it is drawn as it is.
	pose_flip : BirdFlight.BirdPose, BirdFlight.Heading -> StillOnScreen.Flip
	pose_flip = |pose, heading|
		match (pose, heading) {
			(Away(_), _) => AsDrawn
			(_, Rightward) => AsDrawn
			(_, Leftward) => Mirrored
		}
}

expect [Perched, Side(WingsUp), Diving].all(|pose| Bird.pose_flip(pose, Leftward) == Mirrored)
expect [Perched, Side(WingsDown), Diving].all(|pose| Bird.pose_flip(pose, Rightward) == AsDrawn)
expect [Away(WingsUp), Away(WingsDown)].all(|pose| Bird.pose_flip(pose, Leftward) == AsDrawn)
