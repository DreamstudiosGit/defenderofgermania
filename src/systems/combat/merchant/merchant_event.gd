class_name MerchantEvent
extends RefCounted
## Something that happened in a raid tick, for the presentation only.

enum Kind {
	RAID_START,
	DRIVER_PULLED,
	HARNESS_CUT,
	ALARM,
	BOLT_MISSED,
	STRIKE,
	BLOCKED,
	ESCORT_HIT,
	ESCORT_DOWN,
	ESCORT_UP,
	WINDUP,
	PARRY,
	PARRIED,
	LEADER_HIT,
	CAPTURED,
	AMBUSH,
	WAGON_ARRIVED,
	OVER,
}

var kind: Kind
var wagon: int
var escort: int
## The raider: MerchantState.LEADER or a company index.
var raider: int


func _init(
	event_kind: Kind, wagon_index: int = -1, escort_index: int = -1,
	raider_index: int = MerchantState.LEADER
) -> void:
	kind = event_kind
	wagon = wagon_index
	escort = escort_index
	raider = raider_index
