class_name BattleEvent
extends RefCounted
## Something the presentation should show (shouts, volleys, impacts); events live for one tick
## and are not part of the battle state.

enum Kind {
	FIGHT_START, CHARGE, HEDGEHOG, FORMATION, ROUT, RALLY, IMPACT, VOLLEY, LEADER_CAPTURED, SHOT, BLAST
}

var kind: Kind
var side: int
var company: int
var target: int


func _init(
	event_kind: Kind, event_side: int, event_company: int = -1, event_target: int = -1
) -> void:
	kind = event_kind
	side = event_side
	company = event_company
	target = event_target
