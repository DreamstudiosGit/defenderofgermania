extends GutTest
## Recruiting companies: castles, unlocks, yearly limits, costs and army limits.

var _map: MapData
var _cfg: EconomyConfig
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_cfg = EconomyConfig.load_file()
	_state = GameSetup.create(_map, _cfg, 1)
	_activate("welfen")


func test_recruit_joins_the_army_and_costs_gold_people_and_satisfaction() -> void:
	assert_eq(_recruit("BSW", "levy"), "")
	var army := _state.armies_of("welfen")[0]
	assert_eq(army.company_count(), 5)
	assert_eq(army.health[4], 1.0)
	var brunswick := _state.provinces["BSW"]
	assert_eq(_state.houses["welfen"].gold, 200.0 - 20.0)
	assert_almost_eq(brunswick.population, 60.0 - 0.5, 1e-9)
	assert_almost_eq(brunswick.satisfaction, _cfg.start_satisfaction - 2.0, 1e-9)
	assert_eq(brunswick.recruits_left, 2)


func test_units_unlock_with_the_home_castle() -> void:
	_state.houses["welfen"].gold = 1000.0
	assert_eq(_recruit("BSW", "crossbowmen"), RecruitCommand.ERROR_UNIT_LOCKED)
	assert_eq(_recruit("BSW", "knights"), RecruitCommand.ERROR_UNIT_LOCKED)
	_state.provinces["BSW"].castle_level = 2
	assert_eq(_recruit("BSW", "crossbowmen"), "")
	assert_eq(_recruit("BSW", "knights"), RecruitCommand.ERROR_UNIT_LOCKED)
	_state.provinces["BSW"].castle_level = 3
	assert_eq(_recruit("BSW", "knights"), "")


func test_staufer_knights_cost_a_quarter_less() -> void:
	_activate("staufer")
	_state.houses["staufer"].gold = 1000.0
	_state.provinces["SWB"].castle_level = 3
	assert_eq(RecruitCommand.unit_cost(_cfg, "staufer", "knights"), 90.0)
	assert_eq(RecruitCommand.unit_cost(_cfg, "welfen", "knights"), 120.0)
	assert_eq(RecruitCommand.new(_cfg, _map, "staufer", "SWB", "knights").execute(_state), "")
	assert_eq(_state.houses["staufer"].gold, 1000.0 - 90.0)


func test_brabanters_need_market_two_and_trebuchets_a_workshop() -> void:
	_state.houses["welfen"].gold = 1000.0
	assert_eq(_recruit("BSW", "brabanters"), RecruitCommand.ERROR_UNIT_LOCKED)
	assert_eq(_recruit("BSW", "trebuchet"), RecruitCommand.ERROR_UNIT_LOCKED)
	_state.provinces["BSW"].buildings.append_array(["market_2", "workshop"])
	assert_eq(_recruit("BSW", "brabanters"), "")
	assert_eq(_recruit("BSW", "trebuchet"), "")
	assert_almost_eq(_state.provinces["BSW"].population, 60.0 - 0.2, 1e-9)


func test_recruiting_needs_a_castle_in_the_province() -> void:
	assert_eq(_recruit("HOL", "levy"), RecruitCommand.ERROR_NO_CASTLE)
	assert_eq(_recruit("BRM", "levy"), Command.ERROR_NOT_OWNER)
	assert_eq(_recruit("BSW", "archers"), RecruitCommand.ERROR_UNKNOWN_UNIT)


func test_a_province_gives_a_twentieth_of_its_people_per_year() -> void:
	_state.houses["welfen"].gold = 2000.0
	for i: int in 3:
		assert_eq(_recruit("BSW", "levy"), "")
	assert_eq(_recruit("BSW", "levy"), RecruitCommand.ERROR_RECRUIT_LIMIT)
	for i: int in GameState.ROUNDS_PER_YEAR:
		EconomySettlement.settle(_state, _map, _cfg)
	_activate("welfen")
	var brunswick := _state.provinces["BSW"]
	assert_eq(brunswick.recruits_left, PopulationRules.recruit_limit(_cfg, brunswick.population))
	assert_eq(_recruit("BSW", "levy"), "")


func test_full_army_forms_a_new_one_within_the_army_limit() -> void:
	_state.houses["welfen"].gold = 1000.0
	var army := _state.armies_of("welfen")[0]
	var room := _map.campaign.max_companies(true, _state.houses["welfen"].leadership)
	while army.company_count() < room:
		army.add_company("levy")
	assert_eq(_recruit("BSW", "levy"), RecruitCommand.ERROR_NO_ARMY_ROOM)
	_state.provinces["BSW"].castle_level = 2
	assert_eq(_recruit("BSW", "levy"), "")
	var armies := _state.armies_of("welfen")
	assert_eq(armies.size(), 2)
	assert_eq(armies[1].company_count(), 1)
	assert_eq(armies[1].province, "BSW")
	assert_eq(_state.houses["welfen"].leader_army, army.id)


func test_army_under_a_captain_holds_six_companies() -> void:
	var captain := _state.add_army("welfen", "BSW")
	for i: int in _map.campaign.army_size_captain:
		captain.add_company("levy")
	var error := RecruitCommand.new(_cfg, _map, "welfen", "BSW", "levy", captain.id).execute(_state)
	assert_eq(error, RecruitCommand.ERROR_NO_ARMY_ROOM)


func test_chosen_army_must_stand_in_the_province() -> void:
	var army := _state.armies_of("welfen")[0]
	army.province = "HOL"
	var error := RecruitCommand.new(_cfg, _map, "welfen", "BSW", "levy", army.id).execute(_state)
	assert_eq(error, RecruitCommand.ERROR_NO_ARMY_ROOM)


func test_no_recruiting_while_enemies_stand_in_the_province() -> void:
	_state.add_army("staufer", "BSW").add_company("levy")
	assert_eq(_recruit("BSW", "levy"), RecruitCommand.ERROR_ENEMY_PRESENT)


func _recruit(province: String, unit: String) -> String:
	return RecruitCommand.new(_cfg, _map, "welfen", province, unit).execute(_state)


func _activate(house: String) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.ADMINISTRATION
