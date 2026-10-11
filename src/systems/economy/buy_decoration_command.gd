class_name BuyDecorationCommand
extends Command
## Buys a decoration for the home castle; each one once, up to the decoration limit.

const ERROR_UNKNOWN_DECORATION := "TURN_UNKNOWN_DECORATION"
const ERROR_ALREADY_OWNED := "TURN_DECORATION_OWNED"
const ERROR_LIMIT := "TURN_DECORATION_LIMIT"
const ERROR_PREREQUISITE := "TURN_PREREQUISITE_MISSING"

var decoration: String
var _config: EconomyConfig


func _init(config: EconomyConfig, house_id: String, decoration_id: String) -> void:
	_config = config
	house = house_id
	decoration = decoration_id


func validate(state: GameState) -> String:
	var error := super(state)
	if error.is_empty():
		error = _check_decoration(state)
	if error.is_empty():
		error = gold_error(state, _config.decorations[decoration].cost)
	return error


func apply(state: GameState) -> void:
	var owner := state.houses[house]
	owner.gold -= _config.decorations[decoration].cost
	owner.decorations.append(decoration)


func _check_decoration(state: GameState) -> String:
	if not _config.decorations.has(decoration):
		return ERROR_UNKNOWN_DECORATION
	var owned := state.houses[house].decorations
	if decoration in owned:
		return ERROR_ALREADY_OWNED
	if owned.size() >= _config.decoration_limit:
		return ERROR_LIMIT
	var needed := maxi(1, _config.decorations[decoration].home_castle)
	return "" if state.home_castle_level(house) >= needed else ERROR_PREREQUISITE
