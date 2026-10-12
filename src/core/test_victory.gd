extends GutTest
## Legitimacy, subjugation, the time limit and exile after losing the home castle.

var _rules: GameRules
var _state: GameState


func before_all() -> void:
	_rules = GameRules.load_files()


func before_each() -> void:
	_state = GameSetup.create(_rules.map, _rules.economy, 1)


func test_legitimacy_at_the_start() -> void:
	# Two provinces each, prestige 20; the Staufer also hold the regalia on Trifels.
	assert_almost_eq(Victory.legitimacy(_state, _rules, "staufer"), 30.0 + 4.0 + 4.0, 1e-9)
	assert_almost_eq(Victory.legitimacy(_state, _rules, "welfen"), 4.0 + 4.0, 1e-9)
	_state.provinces["AAC"].owner = "welfen"
	_state.provinces["MAI"].owner = "welfen"
	# Aachen 20, Mainz 10, its elector votes for the occupier: 10.
	assert_almost_eq(Victory.legitimacy(_state, _rules, "welfen"), 30.0 + 10.0 + 8.0 + 4.0, 1e-9)


func test_time_limit_crowns_the_most_legitimate_house() -> void:
	Victory.check(_state, _rules)
	assert_false(_state.is_over())
	_state.turn = _rules.map.campaign.max_rounds
	Victory.check(_state, _rules)
	assert_eq(_state.winner, "staufer")
	assert_eq(_state.phase, GameState.Phase.GAME_OVER)


func test_subjugation_when_every_other_house_is_out() -> void:
	for id: String in ["wettiner", "staufer", "wittelsbacher"]:
		Conquest.eliminate(_state, _state.houses[id])
	Victory.check(_state, _rules)
	assert_eq(_state.winner, "welfen")


func test_losing_the_home_castle_means_exile_with_one_army() -> void:
	var welfen := _state.houses["welfen"]
	welfen.decorations.append("banners")
	var leader_army := _state.armies_of("welfen")[0]
	var second := _state.add_army("welfen", "HOL")
	second.add_company("levy")
	Conquest.conquer(_state, _rules, "BSW", "staufer", true)
	assert_eq(_state.provinces["BSW"].owner, "staufer")
	assert_eq(_state.provinces["BSW"].castle_level, 0)
	assert_eq(welfen.exile_rounds, _rules.map.campaign.exile_rounds)
	assert_eq_deep(_state.armies_of("welfen"), [leader_army] as Array[ArmyState])
	assert_true(welfen.decorations.is_empty())
	assert_eq(_state.home_castle_level("welfen"), 0)
	assert_false(_state.is_over())


func test_retaking_the_old_home_ends_the_exile() -> void:
	Conquest.conquer(_state, _rules, "BSW", "staufer", true)
	Conquest.conquer(_state, _rules, "BSW", "welfen", true)
	assert_eq(_state.houses["welfen"].exile_rounds, 0)
	assert_eq(_state.home_castle_level("welfen"), 1, "a razed home castle is a motte again")
	assert_eq(Garrisons.size(_state, _rules, "BSW"), _rules.economy.home_castle[1].garrison)


func test_exile_ends_in_elimination() -> void:
	Conquest.conquer(_state, _rules, "BSW", "staufer", true)
	for i: int in _rules.map.campaign.exile_rounds:
		assert_false(_state.houses["welfen"].is_eliminated)
		Conquest.count_down_exile(_state)
	assert_true(_state.houses["welfen"].is_eliminated)
	assert_eq(_state.provinces["HOL"].owner, Conquest.NEUTRAL)
	assert_true(_state.armies_of("welfen").is_empty())


func test_exiled_house_takes_a_castle_as_its_new_home() -> void:
	Conquest.conquer(_state, _rules, "BSW", "staufer", true)
	Conquest.conquer(_state, _rules, "NUE", "welfen", true)
	var welfen := _state.houses["welfen"]
	assert_eq(welfen.exile_rounds, 0)
	assert_eq(welfen.home_province, "NUE")
	assert_eq(_state.home_castle_level("welfen"), 1)


func test_small_castle_is_no_new_home() -> void:
	Conquest.conquer(_state, _rules, "BSW", "staufer", true)
	_state.provinces["HES"].castle_level = 1
	Conquest.conquer(_state, _rules, "HES", "welfen", true)
	assert_eq(_state.houses["welfen"].home_province, "BSW")
	assert_gt(_state.houses["welfen"].exile_rounds, 0)


func test_house_without_land_or_army_is_eliminated_at_once() -> void:
	_state.remove_army(_state.armies_of("welfen")[0])
	_state.provinces["HOL"].owner = "staufer"
	Conquest.conquer(_state, _rules, "BSW", "staufer", true)
	assert_true(_state.houses["welfen"].is_eliminated)


func test_exile_counts_down_at_settlement_through_the_turn_loop() -> void:
	Conquest.conquer(_state, _rules, "BSW", "staufer", true)
	var turn := _state.turn
	while _state.turn == turn:
		EndPhaseCommand.new(_rules, _state.active_house()).execute(_state)
	assert_eq(_state.houses["welfen"].exile_rounds, _rules.map.campaign.exile_rounds - 1)
