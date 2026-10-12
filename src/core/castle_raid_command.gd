class_name CastleRaidCommand
extends Command
## The leader steals into a foreign castle in or next to his army's province (an adventure: a
## free leader, one a round) to empty its treasury, burn its granary, free its prisoners or
## take the true regalia (CastleRaids).

const ERROR_NO_CASTLE := "RAID_NO_CASTLE"
const ERROR_NO_TARGET := "RAID_NO_TARGET"

var province: String
var target: String
var _rules: GameRules


func _init(rules: GameRules, house_id: String, province_id: String, target_id: String) -> void:
	_rules = rules
	house = house_id
	province = province_id
	target = target_id


func accepts_phase(phase: GameState.Phase) -> bool:
	return phase == GameState.Phase.CAMPAIGN


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	error = Adventures.error(state, house)
	if not error.is_empty():
		return error
	if province not in CastleRaids.castles(state, _rules, house):
		return ERROR_NO_CASTLE
	return "" if target in CastleRaids.targets(state, province) else ERROR_NO_TARGET


## The raid, for playing it live first; null if the command is refused.
func adventure_setup(state: GameState) -> RefCounted:
	if not validate(state).is_empty():
		return null
	return CastleRaids.setup(state, _rules, house, province, target)


func apply(state: GameState) -> void:
	var raid := CastleRaids.setup(state, _rules, house, province, target)
	CastleRaids.apply(state, _rules, raid, province, CastleRaids.play(state, _rules, raid))
