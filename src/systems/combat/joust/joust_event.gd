class_name JoustEvent
extends RefCounted
## Something the presentation should show; events live for one tick and are not part of the
## joust state. Details of a hit stay in the rider (JoustRider.last_*).

enum Kind { PASS_START, SPUR, STRIKE, IMPACT, HIT, UNSEAT, DECIDING_PASS, FINALE, OVER }

var kind: Kind
## The rider it concerns (for HIT the attacker), -1 for both.
var rider: int


func _init(event_kind: Kind, event_rider: int = -1) -> void:
	kind = event_kind
	rider = event_rider
