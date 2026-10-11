class_name AssignLeaderCommand
extends Command
## Puts the free leader at the head of an army: one in the home province while the leader
## is at court, or one in the same province as the leader's current army.

const ERROR_UNKNOWN_ARMY := "TURN_UNKNOWN_ARMY"
const ERROR_LEADER_UNAVAILABLE := "TURN_LEADER_UNAVAILABLE"
const ERROR_ARMY_FULL := "TURN_ARMY_FULL"

var army_id: int
var _rules: CampaignRules


func _init(rules: CampaignRules, house_id: String, target_army: int) -> void:
	_rules = rules
	house = house_id
	army_id = target_army


func validate(state: GameState) -> String:
	var error := super(state)
	if error.is_empty():
		error = _check_army(state)
	if error.is_empty():
		error = _check_leader(state)
	return error


func apply(state: GameState) -> void:
	state.houses[house].leader_army = army_id


func _check_army(state: GameState) -> String:
	var army := state.army(army_id)
	if army == null or army.owner != house:
		return ERROR_UNKNOWN_ARMY
	var leader := state.houses[house]
	if army.company_count() > _rules.max_companies(true, leader.leadership):
		return ERROR_ARMY_FULL
	return ""


func _check_leader(state: GameState) -> String:
	var leader := state.houses[house]
	var army := state.army(army_id)
	if leader.is_leader_captured() or leader.leader_army == army_id:
		return ERROR_LEADER_UNAVAILABLE
	var current := state.army(leader.leader_army)
	if current == null:
		var at_home := army.province == leader.home_province
		return "" if at_home and state.home_castle_level(house) > 0 else ERROR_LEADER_UNAVAILABLE
	if current.province != army.province:
		return ERROR_LEADER_UNAVAILABLE
	var left_behind := current.company_count() > _rules.max_companies(false, 0)
	return ERROR_ARMY_FULL if left_behind else ""
