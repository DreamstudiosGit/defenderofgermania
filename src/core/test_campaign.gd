extends GutTest
## Campaign moves and field battles. A scripted resolver decides battles, so the tests check
## how results are applied, not the auto-resolve odds.

var _rules: GameRules
var _state: GameState
var _setups: Array[BattleSetup] = []
var _attacker_wins := true
var _attacker_health := 0.8
var _defender_health := 0.5
var _attacker_leader_captured := false


func before_each() -> void:
	_rules = GameRules.load_files()
	_rules.resolver = _scripted_battle
	_state = GameSetup.create(_rules.map, _rules.economy, 1)
	_setups.clear()
	_attacker_wins = true
	_attacker_health = 0.8
	_defender_health = 0.5
	_attacker_leader_captured = false


func test_army_moves_into_an_own_neighbour() -> void:
	_campaign("welfen")
	var army := _army("welfen")
	assert_eq(_move("welfen", army, "HOL"), "")
	assert_eq(army.province, "HOL")
	assert_eq(army.moves_left, 0)
	assert_eq(_move("welfen", army, "BSW"), MoveArmyCommand.ERROR_NO_MOVES)


func test_moves_need_a_neighbour_an_own_army_and_the_campaign_phase() -> void:
	_campaign("welfen")
	assert_eq(_move("welfen", _army("welfen"), "BAY"), MoveArmyCommand.ERROR_NOT_NEIGHBOR)
	assert_eq(_move("welfen", _army("staufer"), "TIR"), MoveArmyCommand.ERROR_UNKNOWN_ARMY)
	_state.phase = GameState.Phase.ADMINISTRATION
	assert_eq(_move("welfen", _army("welfen"), "HOL"), Command.ERROR_WRONG_PHASE)


func test_summer_allows_a_second_step_after_an_own_province() -> void:
	_state.turn = GameState.Season.SUMMER
	_campaign("welfen")
	var army := _army("welfen")
	assert_eq(_move("welfen", army, "HOL"), "")
	assert_eq(army.moves_left, 1)
	assert_eq(_move("welfen", army, "BRB"), "")
	assert_eq(_state.provinces["BRB"].owner, "welfen")
	assert_eq(army.moves_left, 0)


func test_summer_step_into_foreign_land_ends_the_move() -> void:
	_state.turn = GameState.Season.SUMMER
	_campaign("welfen")
	var army := _army("welfen")
	assert_eq(_move("welfen", army, "GOS"), "")
	assert_eq(army.moves_left, 0)


func test_open_province_of_a_house_falls_without_a_battle() -> void:
	_campaign("welfen")
	var army := _army("welfen")
	army.province = "GOS"
	assert_eq(_move("welfen", army, "THU"), "")
	assert_true(_setups.is_empty())
	var thuringia := _state.provinces["THU"]
	assert_eq(thuringia.owner, "welfen")
	assert_eq(thuringia.occupied_rounds, _rules.map.campaign.occupation_rounds)


func test_neutral_levy_without_castle_fights_in_the_open() -> void:
	_campaign("welfen")
	assert_eq(_move("welfen", _army("welfen"), "GOS"), "")
	assert_eq(_setups.size(), 1)
	var setup := _setups[0]
	assert_eq(setup.defender.company_count(), 2)
	assert_eq(setup.defender.units[0], "levy")
	assert_eq(setup.defender_wall, 0)
	assert_eq(setup.terrain, "mountains")
	assert_eq(_state.provinces["GOS"].owner, "welfen")


func test_beaten_attacker_falls_back_to_where_it_came_from() -> void:
	_attacker_wins = false
	_campaign("welfen")
	var army := _army("welfen")
	assert_eq(_move("welfen", army, "GOS"), "")
	assert_eq(army.province, "BSW")
	assert_almost_eq(army.health[0], 0.8, 1e-9)
	assert_eq(_state.provinces["GOS"].owner, "neutral")
	assert_almost_eq(_state.provinces["GOS"].garrison_health, 0.5, 1e-9)


func test_field_battle_comes_before_the_levy() -> void:
	var enemy := _state.add_army("staufer", "GOS")
	enemy.add_company("spearmen")
	enemy.add_company("spearmen")
	_campaign("welfen")
	assert_eq(_move("welfen", _army("welfen"), "GOS"), "")
	assert_eq(_setups.size(), 2)
	var field := _setups[0]
	var welfen := _state.houses["welfen"]
	assert_eq(field.attacker.company_count(), 4)
	assert_true(field.attacker.has_leader)
	assert_eq(field.attacker.leadership, welfen.leadership)
	assert_eq(field.defender.owner, "staufer")
	assert_false(field.defender.has_leader)
	assert_null(_state.army(enemy.id), "no Staufer province to retreat to")
	assert_false(_state.houses["staufer"].is_leader_captured())
	assert_eq(_state.provinces["GOS"].owner, "welfen")


func test_beaten_defender_retreats_to_an_own_neighbour() -> void:
	var enemy := _state.add_army("staufer", "SPT")
	enemy.add_company("levy")
	_campaign("welfen")
	var army := _army("welfen")
	army.province = "PFA"
	assert_eq(_move("welfen", army, "SPT"), "")
	assert_eq(enemy.province, "SWB")
	assert_eq(_setups.size(), 1, "the castle is besieged, not stormed")
	assert_true(_state.is_besieging(army))


func test_leader_is_captured_when_the_army_cannot_retreat() -> void:
	var enemy := _army("staufer")
	enemy.province = "GOS"
	_campaign("welfen")
	assert_eq(_move("welfen", _army("welfen"), "GOS"), "")
	var staufer := _state.houses["staufer"]
	assert_eq(staufer.leader_captor, "welfen")
	assert_eq(staufer.leader_army, HouseState.NO_ARMY)
	assert_null(_state.army(enemy.id))


func test_battle_result_can_capture_the_attacking_leader() -> void:
	_attacker_leader_captured = true
	_army("staufer").province = "GOS"
	_campaign("welfen")
	assert_eq(_move("welfen", _army("welfen"), "GOS"), "")
	assert_eq(_state.houses["welfen"].leader_captor, "staufer")
	assert_eq(_army("welfen").province, "GOS")


func test_companies_under_a_fifth_of_their_health_disband() -> void:
	_attacker_health = 0.15
	_campaign("welfen")
	var army := _army("welfen")
	assert_eq(_move("welfen", army, "GOS"), "")
	assert_null(_state.army(army.id))
	var welfen := _state.houses["welfen"]
	assert_false(welfen.is_leader_captured())
	assert_eq(welfen.leader_army, HouseState.NO_ARMY)


func test_battle_prestige_counts_at_settlement() -> void:
	_army("staufer").province = "GOS"
	_campaign("welfen")
	_move("welfen", _army("welfen"), "GOS")
	assert_eq(_state.houses["welfen"].pending_prestige, 6.0, "beat the Staufer and the levy")
	assert_eq(_state.houses["staufer"].pending_prestige, -3.0)
	EconomySettlement.settle(_state, _rules.map, _rules.economy)
	assert_almost_eq(_state.houses["welfen"].prestige, 20.0 * 0.95 + 0.5 + 6.0, 1e-9)
	assert_eq(_state.houses["welfen"].pending_prestige, 0.0)


func test_winter_battle_without_the_captured_leader() -> void:
	_state.turn = GameState.Season.WINTER
	var welfen := _state.houses["welfen"]
	welfen.leader_captor = "staufer"
	welfen.leader_army = HouseState.NO_ARMY
	_campaign("welfen")
	_move("welfen", _army("welfen"), "GOS")
	var setup := _setups[0]
	assert_true(setup.is_winter)
	assert_false(setup.attacker.has_leader)
	assert_eq(setup.attacker.morale_bonus, _rules.combat.morale_leader_captured)


func test_resolver_that_breaks_the_contract_falls_back_to_auto_resolve() -> void:
	_rules.resolver = func(_setup: BattleSetup) -> BattleResult: return BattleResult.new()
	_campaign("welfen")
	assert_eq(_move("welfen", _army("welfen"), "GOS"), "")
	assert_push_error("battle resolver")


func test_recovery_heals_armies_at_settlement() -> void:
	var army := _army("welfen")
	army.health[0] = 0.5
	_state.active_index = _state.turn_order.size() - 1
	_state.phase = GameState.Phase.CAMPAIGN
	EndPhaseCommand.new(_rules, _state.active_house()).execute(_state)
	assert_eq(_state.turn, 1)
	assert_almost_eq(army.health[0], 0.75, 1e-9)


func _scripted_battle(setup: BattleSetup) -> BattleResult:
	_setups.append(setup)
	var result := BattleResult.new()
	result.attacker_won = _attacker_wins
	result.attacker_leader_captured = _attacker_leader_captured
	for i: int in setup.attacker.company_count():
		result.attacker_health.append(_attacker_health)
	for i: int in setup.defender.company_count():
		result.defender_health.append(_defender_health)
	return result


func _campaign(house: String) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.CAMPAIGN
	Movement.start_campaign(_state, _rules.map.campaign, house)


func _army(house: String) -> ArmyState:
	return _state.armies_of(house)[0]


func _move(house: String, army: ArmyState, target: String) -> String:
	return MoveArmyCommand.new(_rules, house, army.id, target).execute(_state)
