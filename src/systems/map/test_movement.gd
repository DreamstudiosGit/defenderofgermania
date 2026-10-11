extends GutTest
## Steps per campaign phase, retreats and recovery.

var _map: MapData
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_state = GameSetup.create(_map, EconomyConfig.load_file(), 1)


func test_armies_get_two_steps_in_summer() -> void:
	var army := _state.armies_of("welfen")[0]
	Movement.start_campaign(_state, _map.campaign, "welfen")
	assert_eq(army.moves_left, 1)
	_state.turn = GameState.Season.SUMMER
	Movement.start_campaign(_state, _map.campaign, "welfen")
	assert_eq(army.moves_left, 2)
	assert_eq(_state.armies_of("staufer")[0].moves_left, 0)


func test_bonus_step_only_follows_an_own_province() -> void:
	assert_eq(Movement.steps_after("welfen", "welfen", 2), 1)
	assert_eq(Movement.steps_after("welfen", "church", 2), 0)
	assert_eq(Movement.steps_after("welfen", "welfen", 1), 0)


func test_retreat_prefers_the_given_province() -> void:
	var army := _state.armies_of("welfen")[0]
	army.province = "BRM"
	assert_eq(Movement.retreat_target(_state, _map, army, "HOL"), "HOL")
	assert_eq(Movement.retreat_target(_state, _map, army, ""), "BSW")
	assert_eq(Movement.retreat_target(_state, _map, army, "TIR"), "BSW")


func test_retreat_avoids_hostile_armies() -> void:
	var army := _state.armies_of("welfen")[0]
	army.province = "BRM"
	_state.armies_of("staufer")[0].province = "BSW"
	assert_eq(Movement.retreat_target(_state, _map, army, "BSW"), "HOL")


func test_no_retreat_without_an_own_neighbour() -> void:
	var army := _state.armies_of("welfen")[0]
	army.province = "FRS"
	assert_eq(Movement.retreat_target(_state, _map, army, "BRM"), "")


func test_companies_recover_faster_at_home() -> void:
	var home := _state.armies_of("welfen")[0]
	var abroad := _state.armies_of("staufer")[0]
	abroad.province = "TIR"
	home.health[0] = 0.5
	home.health[1] = 0.9
	abroad.health[0] = 0.5
	Movement.recover(_state, _map.campaign)
	assert_almost_eq(home.health[0], 0.75, 1e-9)
	assert_eq(home.health[1], 1.0)
	assert_almost_eq(abroad.health[0], 0.6, 1e-9)
