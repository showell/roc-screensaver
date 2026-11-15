## A Roc bird's flight down the endless road: the lamp it leaves, and the one
## it flies to, and where it is and how it looks along the way. The bird sits on
## its perch, then flies diagonally ahead, across the road, to the lamp one
## place further on along the other side, and perches there. The next flight starts
## from that lamp and crosses back, so the bird zigzags down the road for ever.
##
## This file is adapted from roc-apps (`canvas_apps/safari/BirdFlight.roc`) on
## 2026-11-15, and it is allowed to drift from it. The poses, the wing beat, the
## flight's frames, its eased path and its arc are Safari's, copied. What
## differs is where a flight goes: Safari's bird starts on the left and flies
## once from tree to tree, while this one zigzags between lamps, so a flight
## also has a heading, which says which way its side-on stills face.
import Easing
import RoadLamps
import lib.Fraction

## A bird's flight is the lamp it leaves, and the one it flies to.
BirdFlight := { from : RoadLamps.RoadLamp, to : RoadLamps.RoadLamp }.{

	## Where the wings are in a beat.
	WingBeat : [WingsUp, WingsDown]

	## How the bird looks: sitting; side on as it takes off; seen from behind
	## as it flies off; and dropping onto its lamp.
	BirdPose : [
		Perched,
		Side(BirdFlight.WingBeat),
		Away(BirdFlight.WingBeat),
		Diving,
	]

	## Which way a flight crosses the road, as the camera looks down it.
	Heading : [Rightward, Leftward]

	## Where a bird is, in metres: along the road, across it from the middle
	## (negative on the left), and up from the ground.
	Location : { along : F64, across : F64, lift : F64 }

	## A bird at one instant: how it looks, and where it is.
	BirdInstant : { pose : BirdFlight.BirdPose, location : BirdFlight.Location }

	## Where a flight has got to: not begun, so the bird sits on the lamp it
	## will leave, or playing and this many steps in, which is the frame it
	## shows.
	Stage : [Waiting, Playing(U64)]

	## The first flight, from the first lamp on the left.
	first : BirdFlight
	first = BirdFlight.flight_from(RoadLamps.lamp_at(Left, 0))

	## The flight of a bird perched on `perch`: to the lamp one place on, on
	## the other side of the road. Every hop is one place, so the bird's
	## progress down the road never strays from an even pace by more than two
	## nudges, and a camera at a constant speed keeps it in view.
	flight_from : RoadLamps.RoadLamp -> BirdFlight
	flight_from = |perch| BirdFlight.({ from: perch, to: RoadLamps.lamp_at(RoadLamps.other_side(perch.side), perch.place + 1) })

	## The lamp `flight` leaves, and the one it lands on.
	lamps : BirdFlight -> { from : RoadLamps.RoadLamp, to : RoadLamps.RoadLamp }
	lamps = |BirdFlight.(ends)| ends

	is_eq : _

	## The flight after `flight`, from the lamp it lands on.
	next : BirdFlight -> BirdFlight
	next = |flight| BirdFlight.flight_from(flight.to)

	## Which way `flight` crosses the road.
	heading : BirdFlight -> BirdFlight.Heading
	heading = |flight|
		if flight.to.across > flight.from.across {
			Rightward
		} else {
			Leftward
		}

	## How many steps a flight plays, a frame a step.
	frame_count : U64
	frame_count = flight_frames.len()

	## The bird at `stage` of its flight.
	bird_instant_at : BirdFlight, BirdFlight.Stage -> BirdFlight.BirdInstant
	bird_instant_at = |flight, stage|
		match stage {
			Waiting => sitting_on(flight.from)
			Playing(steps_in) =>
				match flight_frames.get(steps_in) {
					Ok({ pose, through }) => {
						pose,
						location: flight_location({ from: lamp_top(flight.from), to: lamp_top(flight.to), through }),
					}
					Err(OutOfBounds) => crash "BirdFlight.bird_instant_at: a stage plays past the flight's last frame"
				}
		}
}

## How far above a straight line the top of its path is, chosen by eye.
flight_arc : F64
flight_arc = 5.0

## How many steps each half of a flap of the wings takes, up or down.
frames_a_half_flap : U64
frames_a_half_flap = 2

## The bird as it sits on top of `lamp`.
sitting_on : RoadLamps.RoadLamp -> BirdFlight.BirdInstant
sitting_on = |lamp| { pose: Perched, location: lamp_top(lamp) }

## The location on top of `lamp`.
lamp_top : RoadLamps.RoadLamp -> BirdFlight.Location
lamp_top = |lamp| { along: lamp.along, across: lamp.across, lift: lamp.lantern.height_metres() }

## How the bird looks through a flight, a frame a step: a flap side on as it
## takes off, seven flaps seen from behind, and a flap's length of diving. The
## seven is chosen by eye.
flight_poses : List(BirdFlight.BirdPose)
flight_poses = [
	flap_poses({ up: Side(WingsUp), down: Side(WingsDown) }),
	List.repeat(flap_poses({ up: Away(WingsUp), down: Away(WingsDown) }), 7).join(),
	List.repeat(Diving, 2 * frames_a_half_flap),
].join()

## One frame of any flight before it is put between two lamps: how the bird
## looks, and how far through the flight it is.
FlightFrame : { pose : BirdFlight.BirdPose, through : Fraction }

## The frames of any flight, one a step: `flight_poses`, each as far through
## the flight as its place in the list, from the start at the first to the end
## at the last.
flight_frames : List(FlightFrame)
flight_frames = {
	last_frame = (flight_poses.len() - 1).to_f64()
	flight_poses.map_with_index(
		|pose, frame| { pose, through: Fraction.of(frame.to_f64() / last_frame) },
	)
}

## One flap of the wings: `up` for its first half and `down` for its second.
flap_poses : { up : BirdFlight.BirdPose, down : BirdFlight.BirdPose } -> List(BirdFlight.BirdPose)
flap_poses = |{ up, down }| {
	half_up = List.repeat(up, frames_a_half_flap)
	half_up.concat(List.repeat(down, frames_a_half_flap))
}

## The location `through` a flight between `from` and `to`, easing out and in
## along a straight line, and raised by an arc over it.
flight_location : {
	from : BirdFlight.Location,
	to : BirdFlight.Location,
	through : Fraction,
} -> BirdFlight.Location
flight_location = |{ from, to, through }| {
	eased = Easing.smoothstep(through)
	between = |start, end| Easing.lerp({ from: start, to: end, fraction: eased })
	share = through.to_f64()
	# 4t(1 - t) is 0 at both ends and 1 halfway, so the arc tops out at `flight_arc`.
	above_line = flight_arc * 4.0 * share * (1.0 - share)
	{
		along: between(from.along, to.along),
		across: between(from.across, to.across),
		lift: between(from.lift, to.lift) + above_line,
	}
}

# A flight is thirty-six frames: one flap side on, seven from behind, and a
# flap's length of diving.
expect BirdFlight.frame_count == 36
expect flight_poses.first() == Ok(Side(WingsUp))
expect flight_poses.last() == Ok(Diving)

# The flights alternate sides, each a place on, so each runs ahead by the
# spacing less two nudges at least.
expect {
	second = BirdFlight.first.next()
	third = second.next()
	BirdFlight.first.heading() == Rightward
		and second.heading() == Leftward
		and third.heading() == Rightward
		and [BirdFlight.first, second, third].all(
			|flight|
				flight.to.place == flight.from.place + 1
					and flight.to.along >= flight.from.along + RoadLamps.lamp_spacing - 2.0 * RoadLamps.most_nudge,
		)
}

# The bird starts and ends a flight on the lamp tops, and the arc lifts it
# halfway.
expect {
	flight = BirdFlight.first
	at_start = flight.bird_instant_at(Playing(0)).location
	at_end = flight.bird_instant_at(Playing(BirdFlight.frame_count - 1)).location
	at_start == lamp_top(flight.from) and at_end == lamp_top(flight.to)
}
expect {
	from = { along: 0.0, across: -3.5, lift: 6.0 }
	to = { along: 30.0, across: 3.5, lift: 6.0 }
	flight_location({ from, to, through: Fraction.of(0.5) }) == { along: 15.0, across: 0.0, lift: 11.0 }
}
