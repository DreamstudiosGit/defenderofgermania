extends GutTest

var _map: MapData
var _cfg: EconomyConfig
var _rules: GameRules


func before_all() -> void:
	_rules = GameRules.load_files()
	_map = _rules.map
	_cfg = _rules.economy


func test_new_game_starts_every_house_with_gdd_values() -> void:
	var state := GameSetup.create(_map, _cfg, 1)
	assert_eq(state.houses.size(), 4)
	for house: HouseState in state.houses.values():
		assert_eq(house.gold, 200.0)
		assert_eq(house.grain, 300.0)
		assert_eq(house.prestige, 20.0)
		assert_eq(house.tax_rate, 15)
		assert_eq(house.ration, 3)
		var armies := state.armies_of(house.id)
		assert_eq(armies.size(), 1)
		assert_eq(armies[0].province, house.home_province)
		assert_eq(armies[0].units.size(), 4)
		assert_eq(armies[0].health, PackedFloat64Array([1.0, 1.0, 1.0, 1.0]))
		assert_eq(house.leader_army, armies[0].id)
		assert_eq(house.leadership + house.lance + house.blade, 9)


func test_seasons_cycle_from_spring() -> void:
	var state := GameState.new()
	assert_eq(state.season(), GameState.Season.SPRING)
	assert_eq(state.rounds_since_autumn(), 2)
	state.turn = 6
	assert_eq(state.season(), GameState.Season.AUTUMN)
	assert_eq(state.rounds_since_autumn(), 0)
	state.turn = 7
	assert_eq(state.rounds_since_autumn(), 1)


func test_save_round_trip_keeps_everything() -> void:
	var state := _played_state(5)
	_add_campaign_details(state)
	var copy := GameState.from_dict(state.to_dict())
	assert_not_null(copy)
	assert_eq_deep(copy.to_dict(), state.to_dict())
	assert_eq(copy.checksum(), state.checksum())


func test_loaded_game_continues_identically() -> void:
	var state := _played_state(5)
	var copy := GameState.from_bytes(state.to_bytes())
	for i: int in 8:
		EconomySettlement.settle(state, _map, _cfg)
		EconomySettlement.settle(copy, _map, _cfg)
	assert_eq(copy.checksum(), state.checksum())


func test_unknown_save_version_is_rejected() -> void:
	var data := _played_state(0).to_dict()
	data["version"] = GameState.SAVE_VERSION + 1
	assert_null(GameState.from_dict(data))
	assert_push_error("save version")


func test_broken_save_is_rejected() -> void:
	var data := _played_state(0).to_dict()
	data.erase("houses")
	assert_null(GameState.from_dict(data))
	assert_push_error("houses: missing")


func test_game_saved_mid_campaign_continues_identically() -> void:
	var state := GameSetup.create(_map, _cfg, 42)
	_end_phase(state)
	var army := state.armies_of(state.active_house())[0]
	var target: String = _map.provinces[army.province].neighbors[0]
	MoveArmyCommand.new(_rules, state.active_house(), army.id, target).execute(state)
	var copy := GameState.from_bytes(state.to_bytes())
	assert_eq(copy.phase, GameState.Phase.CAMPAIGN)
	for i: int in 30:
		_end_phase(state)
		_end_phase(copy)
	assert_eq(copy.turn, state.turn)
	assert_eq(copy.checksum(), state.checksum())


func test_save_with_unknown_phase_is_rejected() -> void:
	var data := _played_state(0).to_dict()
	data["phase"] = 99
	assert_null(GameState.from_dict(data))
	assert_push_error("phase: unknown value")


func _add_campaign_details(state: GameState) -> void:
	var house := state.houses["welfen"]
	house.leader_captor = "staufer"
	house.leader_army = HouseState.NO_ARMY
	house.pending_prestige = 3.0
	house.exile_rounds = 2
	var army := state.add_army("welfen", "HOL")
	army.add_company("knights", 0.42)
	army.moves_left = 1
	var province := state.provinces["HOL"]
	province.garrison_health = 0.65
	province.recruits_left = 2
	province.constructions.append(ConstructionState.create("granary", 1))
	province.constructions.append(ConstructionState.create(ConstructionState.CASTLE, 2))
	state.grain_traded = -150.0
	state.phase = GameState.Phase.CAMPAIGN
	state.active_index = 2


func _end_phase(state: GameState) -> void:
	EndPhaseCommand.new(_rules, state.active_house()).execute(state)


func _played_state(rounds: int) -> GameState:
	var state := GameSetup.create(_map, _cfg, 42)
	for i: int in rounds:
		EconomySettlement.settle(state, _map, _cfg)
	return state
