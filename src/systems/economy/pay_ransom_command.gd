class_name PayRansomCommand
extends Command
## Buys the captured leader free; a captor house receives the ransom. The leader returns to
## the home castle.

const ERROR_NOT_CAPTURED := "TURN_LEADER_NOT_CAPTURED"

var _config: EconomyConfig


func _init(config: EconomyConfig, house_id: String) -> void:
	_config = config
	house = house_id


static func ransom(state: GameState, cfg: EconomyConfig, house_id: String) -> float:
	return cfg.ransom_base + cfg.ransom_per_home_castle_level * state.home_castle_level(house_id)


func validate(state: GameState) -> String:
	var error := super(state)
	if error.is_empty() and not state.houses[house].is_leader_captured():
		error = ERROR_NOT_CAPTURED
	if error.is_empty():
		error = gold_error(state, ransom(state, _config, house))
	return error


func apply(state: GameState) -> void:
	var owner := state.houses[house]
	var amount := ransom(state, _config, house)
	owner.gold -= amount
	var captor: HouseState = state.houses.get(owner.leader_captor)
	if captor != null:
		captor.gold += amount
	owner.leader_captor = ""
	owner.leader_army = HouseState.NO_ARMY
