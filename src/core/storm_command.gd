class_name StormCommand
extends Command
## Storms the castle an army besieges: a battle against the garrison behind its walls.
## Victory takes the castle (one level lower), defeat throws the army back.

const ERROR_UNKNOWN_ARMY := "TURN_UNKNOWN_ARMY"
const ERROR_NOT_BESIEGING := "TURN_NOT_BESIEGING"
const ERROR_SIEGE_DONE := "TURN_SIEGE_DONE"

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
	return siege_error(state, _rules, army)


## Why the army cannot storm or bombard now; "" if it can (a besieger acts once a round).
static func siege_error(state: GameState, rules: GameRules, army: ArmyState) -> String:
	if CrownRules.is_doing_penance(state, army.owner):
		return MoveArmyCommand.ERROR_PENANCE
	var defended := Garrisons.size(state, rules, army.province) > 0
	if not state.is_besieging(army) or not defended:
		return ERROR_NOT_BESIEGING
	return ERROR_SIEGE_DONE if army.siege_turn == state.turn else ""


## The storm battle, for fighting it live first; null if the command is refused.
func battle_setup(state: GameState) -> BattleSetup:
	if not validate(state).is_empty():
		return null
	var army := state.army(army_id)
	var wall := Garrisons.wall(state, _rules, army.province)
	return CampaignBattles.garrison_battle(state, _rules, army, wall, army.province)


func apply(state: GameState) -> void:
	var army := state.army(army_id)
	var province_id := army.province
	army.moves_left = 0
	army.siege_turn = state.turn
	var wall := Garrisons.wall(state, _rules, province_id)
	if CampaignBattles.fight_garrison(state, _rules, army, wall, ""):
		Conquest.conquer(state, _rules, province_id, house, true)
