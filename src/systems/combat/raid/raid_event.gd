class_name RaidEvent
extends RefCounted
## Something the presentation should show; events live for one tick and are not raid state.

enum Kind {
	ENGAGE, STRIKE, PARRY, HIT, BLOCKED, PARRIED, DOWN, TIRED, ALARM, REINFORCEMENT, SNEAK_IN,
	SNEAK_OUT, DEED_START, DEED_DONE
}

const LEADER := -1

var kind: Kind
## Guard index, or LEADER.
var fighter: int
var height: int


func _init(event_kind: Kind, event_fighter: int = LEADER, event_height: int = -1) -> void:
	kind = event_kind
	fighter = event_fighter
	height = event_height
