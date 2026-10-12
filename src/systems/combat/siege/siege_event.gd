class_name SiegeEvent
extends RefCounted
## Something the presentation shows after a shot: a hit, a part falling or burning, the
## garrison losing health, the breach, or the counterfire that cost a shot.

enum Kind {
	HIT,
	MISS_SHORT,
	MISS_LONG,
	YARD,
	DESTROYED,
	CRUSHED,
	IGNITED,
	BURNED,
	GARRISON,
	BREACH,
	COUNTERFIRE,
}
enum Cause { NONE, HIT, FELL, CRUSHED, BURNT }

var kind: Kind
## Part index in the castle (-1 when none).
var part: int = -1
## For CRUSHED: the part that fell onto `part`.
var other: int = -1
## HP lost for HIT, CRUSHED and BURNED; health share for GARRISON.
var amount: float = 0.0
var cause: Cause = Cause.NONE


static func make(
	event_kind: Kind, at_part: int = -1, value: float = 0.0, from_part: int = -1,
	why: Cause = Cause.NONE
) -> SiegeEvent:
	var event := SiegeEvent.new()
	event.kind = event_kind
	event.part = at_part
	event.amount = value
	event.other = from_part
	event.cause = why
	return event
