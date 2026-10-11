class_name MoveArmyCommand
extends Command
## Moves an army into a neighbouring province. Hostile armies there are fought one after
## another; then a foreign province is taken, its open-field levy fought, or its castle
## besieged (StormCommand or starvation at settlement decide the siege).

const ERROR_UNKNOWN_ARMY := "TURN_UNKNOWN_ARMY"
const ERROR_NOT_NEIGHBOR := "TURN_NOT_NEIGHBOR"
const ERROR_NO_MOVES := "TURN_NO_MOVES_LEFT"

var army_id: int
var target: String
var _rules: GameRules


func _init(rules: GameRules, house_id: String, moving_army: int, province_id: String) -> void:
	_rules = rules
	house = house_id
	army_id = moving_army
	target = province_id


func accepts_phase(phase: GameState.Phase) -> bool:
	return phase == GameState.Phase.CAMPAIGN


func validate(state: GameState) -> String:
	var error := super(state)
	if error.is_empty():
		error = _check_move(state)
	return error


func apply(state: GameState) -> void:
	var army := state.army(army_id)
	var came_from := army.province
	army.province = target
	army.moves_left = Movement.steps_after(house, state.provinces[target].owner, army.moves_left)
	var enemies := state.armies_in(target).filter(
		func(other: ArmyState) -> bool: return other.owner != house
	)
	for enemy: ArmyState in enemies:
		army.moves_left = 0
		var won := CampaignBattles.fight_army(state, _rules, army, enemy, came_from)
		if not won or state.army(army_id) == null:
			return
	if state.provinces[target].owner == house:
		return
	if Garrisons.size(state, _rules, target) == 0:
		Conquest.conquer(state, _rules, target, house, false)
	elif Garrisons.wall(state, _rules, target) == 0:
		if CampaignBattles.fight_garrison(state, _rules, army, 0, came_from):
			Conquest.conquer(state, _rules, target, house, false)


func _check_move(state: GameState) -> String:
	var army := state.army(army_id)
	if army == null or army.owner != house:
		return ERROR_UNKNOWN_ARMY
	if not _rules.map.are_neighbors(army.province, target):
		return ERROR_NOT_NEIGHBOR
	return "" if army.moves_left > 0 else ERROR_NO_MOVES
