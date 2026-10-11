class_name StormCommand
extends Command
## Storms the castle an army besieges: a battle against the garrison behind its walls.
## Victory takes the castle (one level lower), defeat throws the army back.

const ERROR_UNKNOWN_ARMY := "TURN_UNKNOWN_ARMY"
const ERROR_NOT_BESIEGING := "TURN_NOT_BESIEGING"

var army_id: int
var _rules: GameRules


func _init(rules: GameRules, house_id: String, storming_army: int) -> void:
	_rules = rules
	house = house_id
	army_id = storming_army


func accepts_phase(phase: GameState.Phase) -> bool:
	return phase == GameState.Phase.CAMPAIGN


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	var army := state.army(army_id)
	if army == null or army.owner != house:
		return ERROR_UNKNOWN_ARMY
	var defended := Garrisons.size(state, _rules, army.province) > 0
	return "" if state.is_besieging(army) and defended else ERROR_NOT_BESIEGING


func apply(state: GameState) -> void:
	var army := state.army(army_id)
	var province_id := army.province
	army.moves_left = 0
	var wall := Garrisons.wall(state, _rules, province_id)
	if CampaignBattles.fight_garrison(state, _rules, army, wall, ""):
		Conquest.conquer(state, _rules, province_id, house, true)
