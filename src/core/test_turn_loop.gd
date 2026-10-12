extends GutTest
## Round flow: playing order, phases per house, settlement and the end of the game.

var _rules: GameRules
var _state: GameState


func before_all() -> void:
	_rules = GameRules.load_files()


func before_each() -> void:
	_state = GameSetup.create(_rules.map, _rules.economy, 1)


func test_new_game_starts_with_the_first_house_in_administration() -> void:
	assert_eq(_state.turn, 0)
	assert_eq(_state.phase, GameState.Phase.ADMINISTRATION)
	assert_eq(_state.turn_order.size(), 4)
	assert_eq(_state.active_house(), _state.turn_order[0])


func test_lowest_prestige_plays_first() -> void:
	var prestige := {"welfen": 30.0, "wettiner": 20.0, "staufer": 10.0, "wittelsbacher": 25.0}
	for id: String in prestige:
		_state.houses[id].prestige = prestige[id]
	TurnLoop.start_round(_state)
	var expected: Array[String] = ["staufer", "wettiner", "wittelsbacher", "welfen"]
	assert_eq_deep(_state.turn_order, expected)


func test_the_seed_breaks_ties() -> void:
	var again := GameSetup.create(_rules.map, _rules.economy, 1)
	assert_eq_deep(again.turn_order, _state.turn_order)
	var orders := {}
	for seed_value: int in 20:
		orders[str(GameSetup.create(_rules.map, _rules.economy, seed_value).turn_order)] = true
	assert_gt(orders.size(), 1)


func test_each_house_plays_administration_then_campaign() -> void:
	var first := _state.active_house()
	assert_eq(_end(first), "")
	assert_eq(_state.phase, GameState.Phase.CAMPAIGN)
	assert_eq(_state.active_house(), first)
	assert_eq(_state.armies_of(first)[0].moves_left, 1)
	assert_eq(_end(first), "")
	assert_eq(_state.phase, GameState.Phase.ADMINISTRATION)
	assert_eq(_state.active_house(), _state.turn_order[1])


func test_only_the_active_house_ends_its_phase() -> void:
	assert_eq(_end(_state.turn_order[1]), Command.ERROR_NOT_ACTIVE)
	assert_eq(_state.active_house(), _state.turn_order[0])


func test_settlement_runs_after_the_last_house() -> void:
	var gold := _state.houses["welfen"].gold
	_play_round()
	assert_eq(_state.turn, 1)
	var waits := _state.events.pending > 0
	assert_eq(_state.phase == GameState.Phase.EVENT, waits, "event phase only for open choices")
	assert_ne(_state.houses["welfen"].gold, gold)


func test_eliminated_houses_are_skipped() -> void:
	var skipped := _state.turn_order[1]
	Conquest.eliminate(_state, _state.houses[skipped])
	var first := _state.active_house()
	_end(first)
	_end(first)
	assert_eq(_state.active_house(), _state.turn_order[2])
	_play_round()
	assert_false(skipped in _state.turn_order)
	assert_eq(_state.turn_order.size(), 3)


func test_game_ends_after_the_last_round_with_the_most_legitimate_house() -> void:
	_state.turn = _rules.map.campaign.max_rounds - 1
	_play_round()
	assert_true(_state.is_over())
	assert_eq(_state.phase, GameState.Phase.GAME_OVER)
	# Only the Staufer hold a legitimacy province at the start: Speyer & Trifels.
	assert_eq(_state.winner, "staufer")
	assert_eq(_end(_state.turn_order[0]), Command.ERROR_GAME_OVER)


func test_subjugation_ends_the_game_after_the_campaign() -> void:
	var first := _state.active_house()
	for house: HouseState in _state.houses.values():
		if house.id != first:
			Conquest.eliminate(_state, house)
	_end(first)
	_end(first)
	assert_true(_state.is_over())
	assert_eq(_state.winner, first)


func _play_round() -> void:
	var turn := _state.turn
	while _state.turn == turn and not _state.is_over():
		assert_eq(_end(_state.active_house()), "")


func _end(house: String) -> String:
	return EndPhaseCommand.new(_rules, house).execute(_state)
