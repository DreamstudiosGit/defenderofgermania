class_name ForgeRegaliaCommand
extends Command
## Commissions forged regalia from a high enough home castle; they are ready after the
## settlements of their build time (CrownSettlement).

const ERROR_FORGED := "CROWN_REGALIA_FORGED"
const ERROR_CASTLE := "CROWN_REGALIA_CASTLE"

var _map: MapData


func _init(map: MapData, house_id: String) -> void:
	_map = map
	house = house_id


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	if house in state.crown.forged_regalia or state.crown.forging.has(house):
		return ERROR_FORGED
	if state.home_castle_level(house) < _map.crown.forged_regalia_home_castle:
		return ERROR_CASTLE
	return gold_error(state, _map.crown.forged_regalia_cost)


func apply(state: GameState) -> void:
	state.houses[house].gold -= _map.crown.forged_regalia_cost
	state.crown.forging[house] = _map.crown.forged_regalia_rounds
