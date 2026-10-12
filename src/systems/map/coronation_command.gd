class_name CoronationCommand
extends Command
## Calls the coronation at the winter court: with regalia, a held coronation site, a willing
## archbishop and enough electors' votes the house is crowned and wins the game.

const ERROR_NOT_WINTER := "CROWN_NOT_WINTER"

var _map: MapData


func _init(map: MapData, house_id: String) -> void:
	_map = map
	house = house_id


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	if state.season() != GameState.Season.WINTER:
		return ERROR_NOT_WINTER
	return CrownRules.coronation_error(state, _map, house)


func apply(state: GameState) -> void:
	state.crown.crowned_at = CrownRules.coronation_site(state, _map, house)
	state.winner = house
	state.phase = GameState.Phase.GAME_OVER
