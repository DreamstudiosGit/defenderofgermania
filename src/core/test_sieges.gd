extends GutTest
## Castles without an army: siege on arrival, starvation, storm, garrisons and castle damage.

var _rules: GameRules
var _state: GameState
var _setups: Array[BattleSetup] = []
var _attacker_wins := true


func before_each() -> void:
	_rules = GameRules.load_files()
	_rules.resolver = _scripted_battle
	_state = GameSetup.create(_rules.map, _rules.economy, 1)
	_setups.clear()
	_attacker_wins = true


func test_castle_without_an_army_is_besieged_on_arrival() -> void:
	var army := _besiege_trifels()
	assert_true(_setups.is_empty())
	assert_eq(_state.provinces["SPT"].owner, "staufer")
	assert_true(_state.is_besieging(army))


func test_starving_garrison_loses_fifteen_percent_per_round() -> void:
	_besiege_trifels()
	Garrisons.starve(_state, _rules)
	assert_almost_eq(_state.provinces["SPT"].garrison_health, 0.85, 1e-9)
	Garrisons.starve(_state, _rules)
	assert_almost_eq(_state.provinces["SPT"].garrison_health, 0.70, 1e-9)


func test_granary_halves_starvation() -> void:
	_besiege_trifels()
	_state.provinces["SPT"].buildings.append("granary")
	Garrisons.starve(_state, _rules)
	assert_almost_eq(_state.provinces["SPT"].garrison_health, 0.925, 1e-9)


func test_unbesieged_garrison_does_not_starve_but_recovers() -> void:
	var trifels := _state.provinces["SPT"]
	trifels.garrison_health = 0.5
	Garrisons.starve(_state, _rules)
	assert_eq(trifels.garrison_health, 0.5)
	Garrisons.recover(_state, _rules)
	assert_almost_eq(trifels.garrison_health, 0.75, 1e-9)


func test_starved_garrison_surrenders_and_the_castle_loses_a_level() -> void:
	_besiege_trifels()
	var trifels := _state.provinces["SPT"]
	trifels.garrison_health = 0.3
	Garrisons.starve(_state, _rules)
	assert_eq(trifels.owner, "welfen")
	assert_eq(trifels.castle_level, 2)
	assert_eq(trifels.occupied_rounds, _rules.map.campaign.occupation_rounds)
	assert_eq(trifels.garrison_health, 1.0)


func test_besiegers_pay_a_quarter_more_upkeep() -> void:
	var calm := GameSetup.create(_rules.map, _rules.economy, 1)
	_besiege_trifels()
	EconomySettlement.settle(calm, _rules.map, _rules.economy)
	EconomySettlement.settle(_state, _rules.map, _rules.economy)
	var start_army_upkeep := 6.0
	var extra := start_army_upkeep * (_rules.economy.siege_upkeep_multiplier - 1.0)
	assert_almost_eq(calm.houses["welfen"].gold - _state.houses["welfen"].gold, extra, 1e-9)


func test_storm_fights_the_garrison_behind_the_walls() -> void:
	var army := _besiege_trifels()
	assert_eq(_storm(army), "")
	assert_eq(_setups.size(), 1)
	var setup := _setups[0]
	assert_eq(setup.defender_wall, 3)
	assert_eq(setup.defender.company_count(), 3)
	assert_eq(setup.defender.owner, "staufer")
	assert_eq(setup.terrain, "forest")
	var trifels := _state.provinces["SPT"]
	assert_eq(trifels.owner, "welfen")
	assert_eq(trifels.castle_level, 2)


func test_failed_storm_throws_the_army_back() -> void:
	_attacker_wins = false
	_state.provinces["PFA"].owner = "welfen"
	var army := _besiege_trifels()
	assert_eq(_storm(army), "")
	assert_eq(army.province, "PFA")
	assert_eq(_state.provinces["SPT"].owner, "staufer")
	assert_almost_eq(_state.provinces["SPT"].garrison_health, 0.5, 1e-9)
	assert_eq(_storm(army), StormCommand.ERROR_NOT_BESIEGING)


func test_storm_needs_a_siege_in_the_campaign_phase() -> void:
	_campaign("welfen")
	var army := _state.armies_of("welfen")[0]
	assert_eq(_storm(army), StormCommand.ERROR_NOT_BESIEGING)
	army.province = "SPT"
	_state.phase = GameState.Phase.ADMINISTRATION
	assert_eq(_storm(army), Command.ERROR_WRONG_PHASE)


func test_neutral_castle_is_held_by_its_levy() -> void:
	assert_eq(Garrisons.size(_state, _rules, "AAC"), 2)
	assert_eq(Garrisons.wall(_state, _rules, "AAC"), 3)
	assert_eq(Garrisons.size(_state, _rules, "BOH"), 8)
	assert_eq(Garrisons.size(_state, _rules, "GOS"), 2)


func test_house_garrisons_follow_the_castle_tables() -> void:
	assert_eq(Garrisons.size(_state, _rules, "BSW"), 1)
	assert_eq(Garrisons.size(_state, _rules, "NUE"), 2)
	assert_eq(Garrisons.size(_state, _rules, "HOL"), 0)
	_state.provinces["BSW"].castle_level = 5
	assert_eq(Garrisons.size(_state, _rules, "BSW"), 4)
	assert_eq(Garrisons.wall(_state, _rules, "BSW"), 4)


func test_broken_garrison_defends_nothing() -> void:
	_state.provinces["NUE"].garrison_health = 0.1
	assert_eq(Garrisons.size(_state, _rules, "NUE"), 0)


func test_captured_home_castle_is_capped_at_the_province_table() -> void:
	_state.provinces["BSW"].castle_level = 5
	Conquest.conquer(_state, _rules, "BSW", "staufer", true)
	assert_eq(_state.provinces["BSW"].castle_level, 3)


func _besiege_trifels() -> ArmyState:
	_campaign("welfen")
	var army := _state.armies_of("welfen")[0]
	army.province = "PFA"
	assert_eq(MoveArmyCommand.new(_rules, "welfen", army.id, "SPT").execute(_state), "")
	return army


func _storm(army: ArmyState) -> String:
	return StormCommand.new(_rules, "welfen", army.id).execute(_state)


func _campaign(house: String) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.CAMPAIGN
	Movement.start_campaign(_state, _rules.map.campaign, house)


func _scripted_battle(setup: BattleSetup) -> BattleResult:
	_setups.append(setup)
	var result := BattleResult.new()
	result.attacker_won = _attacker_wins
	for i: int in setup.attacker.company_count():
		result.attacker_health.append(0.8)
	for i: int in setup.defender.company_count():
		result.defender_health.append(0.5)
	return result
