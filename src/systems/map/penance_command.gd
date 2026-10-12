class_name PenanceCommand
extends Command
## A banned house does penance: taler (halved by the chapel) and prestige lift the ban, and
## its armies may not campaign for a while.

const ERROR_NOT_BANNED := "CROWN_NOT_BANNED"

var _map: MapData


func _init(map: MapData, house_id: String) -> void:
	_map = map
	house = house_id


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	if not state.houses[house].is_banned:
		return ERROR_NOT_BANNED
	return gold_error(state, CrownRules.penance_gold(state, _map, house))


func apply(state: GameState) -> void:
	var penitent := state.houses[house]
	penitent.gold -= CrownRules.penance_gold(state, _map, house)
	penitent.prestige = maxf(penitent.prestige - _map.crown.penance_prestige, 0.0)
	penitent.is_banned = false
	state.crown.penance_until[house] = state.turn + _map.crown.penance_campaign_rounds
