class_name Command
extends RefCounted
## A player action. Callers run execute(), so every action is validated before it applies;
## subclasses get the balancing data they need through their constructor. Only the active
## house may act, and only in a phase the command accepts.

const ERROR_UNKNOWN_HOUSE := "ERROR_UNKNOWN_HOUSE"
const ERROR_GAME_OVER := "TURN_GAME_OVER"
const ERROR_NOT_ACTIVE := "TURN_NOT_ACTIVE_HOUSE"
const ERROR_WRONG_PHASE := "TURN_WRONG_PHASE"
const ERROR_UNKNOWN_PROVINCE := "TURN_UNKNOWN_PROVINCE"
const ERROR_NOT_OWNER := "TURN_NOT_YOUR_PROVINCE"
const ERROR_NOT_ENOUGH_GOLD := "TURN_NOT_ENOUGH_GOLD"

var house: String


## Returns "" if the command may apply, otherwise a text key from data/i18n/texts.csv.
func validate(state: GameState) -> String:
	if not state.houses.has(house):
		return ERROR_UNKNOWN_HOUSE
	if state.is_over():
		return ERROR_GAME_OVER
	if state.active_house() != house:
		return ERROR_NOT_ACTIVE
	return "" if accepts_phase(state.phase) else ERROR_WRONG_PHASE


func accepts_phase(phase: GameState.Phase) -> bool:
	return phase == GameState.Phase.ADMINISTRATION


func apply(_state: GameState) -> void:
	pass


func execute(state: GameState) -> String:
	var error := validate(state)
	if error.is_empty():
		apply(state)
	return error


func owned_province_error(state: GameState, province_id: String) -> String:
	if not state.provinces.has(province_id):
		return ERROR_UNKNOWN_PROVINCE
	return "" if state.provinces[province_id].owner == house else ERROR_NOT_OWNER


func gold_error(state: GameState, cost: float) -> String:
	return "" if state.houses[house].gold >= cost else ERROR_NOT_ENOUGH_GOLD
