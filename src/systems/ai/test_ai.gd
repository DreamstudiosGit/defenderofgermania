extends GutTest
## The computer opponents (GDD "KI-Gegner"): personalities and difficulties from the data, a
## computer-only campaign that runs and repeats exactly, and the decision levels at work —
## the coronation the moment it is possible, grain for the hungry, the home guard, the
## difficulty's income and minigame skill.

const ROUNDS := 8

var _config: AiConfig


func before_all() -> void:
	_config = AiConfig.load_file()


func test_personalities_and_difficulties_follow_the_gdd() -> void:
	assert_eq(_config.personality_of("welfen"), "merchant")
	assert_eq(_config.personality_of("wettiner"), "builder")
	assert_eq(_config.personality_of("staufer"), "conqueror")
	assert_eq(_config.personality_of("wittelsbacher"), "diplomat")
	assert_eq(_config.difficulties.size(), 4)
	assert_eq(_config.difficulty(0).suboptimal_share, 0.3, "the squire errs in 30 %")
	assert_true(_config.difficulty(3).coalition, "the emperor forges coalitions")
	var economy := EconomyConfig.load_file()
	assert_eq(economy.computer_income, PackedFloat64Array([0.8, 1.0, 1.15, 1.3]))
	assert_gt(_config.weight("merchant", "economy"), _config.weight("merchant", "military"))
	assert_gt(_config.weight("conqueror", "military"), 1.0)


func test_a_computer_campaign_runs_and_repeats_exactly() -> void:
	var first := _computer_game(7)
	var second := _computer_game(7)
	assert_eq(first.state.turn, ROUNDS)
	assert_eq(first.state.checksum(), second.state.checksum(), "same seed, same game")
	var ai: AiPlayer = first.get_meta("ai")
	assert_eq(ai.logs.size(), 4, "every house weighed its options")


func test_the_coronation_is_called_the_moment_it_is_possible() -> void:
	var session := _computer_session(3, 1)
	var state := session.state
	state.turn = 3
	state.phase = GameState.Phase.ADMINISTRATION
	state.active_index = state.turn_order.find("welfen")
	for id: String in ["SPT", "AAC"]:
		state.provinces[id].owner = "welfen"
	for id: String in ["KOE", "TRI", "PFA", "BRB"]:
		state.crown.set_favour(id, "welfen", 60.0, 100.0)
	(session.get_meta("ai") as AiPlayer).play_phase(state)
	assert_eq(state.winner, "welfen")


func test_a_hungry_house_buys_grain() -> void:
	var session := _computer_session(5, 1)
	var state := session.state
	state.phase = GameState.Phase.ADMINISTRATION
	state.active_index = state.turn_order.find("welfen")
	state.houses["welfen"].grain = 0.0
	(session.get_meta("ai") as AiPlayer).play_phase(state)
	var welfen := state.houses["welfen"]
	assert_true(welfen.grain > 0.0 or welfen.ration < 3, "bought grain or cut the ration")


func test_the_only_army_guards_a_threatened_home() -> void:
	var session := _computer_session(5, 1)
	var state := session.state
	var rules := session.rules
	var army := state.army(state.houses["welfen"].leader_army)
	var raiders := state.add_army("staufer", "MAG")
	for _i: int in 6:
		raiders.add_company("knights")
	var turn := AiTurn.new(state, rules, _config, "welfen", AiLog.new())
	assert_true(AiCampaign.must_guard(turn, army), "knights two steps away")
	state.remove_army(raiders)
	assert_false(AiCampaign.must_guard(turn, army))


func test_difficulty_sets_income_and_minigame_skill() -> void:
	var session := _computer_session(5, 3)
	var state := session.state
	var rules := session.rules
	var emperor := state.houses["welfen"]
	assert_eq(rules.economy.income_factor(emperor), 1.3)
	assert_eq(Adventures.auto_skill(state, rules, "welfen"), 3)
	var income := EconomyBreakdown.income(state, rules.map, rules.economy, "welfen")
	assert_eq(income[income.size() - 1].label_key, "ECONOMY_TERM_DIFFICULTY")
	emperor.personality = ""
	assert_eq(rules.economy.income_factor(emperor), 1.0, "humans earn plainly")


func test_a_squire_sometimes_takes_a_worse_option() -> void:
	var session := _computer_session(5, 0)
	var turn := AiTurn.new(session.state, session.rules, _config, "welfen", AiLog.new())
	var worse := 0
	for _i: int in 200:
		var options: Array[AiOption] = [
			AiOption.create("best", 2.0, null), AiOption.create("worse", 1.0, null)
		]
		if turn.choose(options).label == "worse":
			worse += 1
	assert_between(worse, 35, 85, "about 30 % of 200")


func _computer_game(seed_value: int) -> CampaignSession:
	var rules := GameRules.load_files()
	var ai := AiPlayer.new(rules, _config)
	var player := func(state: GameState) -> void:
		if state.turn >= ROUNDS:
			state.phase = GameState.Phase.GAME_OVER
			return
		ai.play_phase(state)
	var none: Array[String] = []
	var computers := AiPlayer.opponents(_config, rules.map.houses, none)
	var session := CampaignSession.create(rules, none, seed_value, computers, player)
	session.set_meta("ai", ai)
	return session


## A session whose computer houses wait (the first house is human, so nothing runs ahead).
func _computer_session(seed_value: int, difficulty: int) -> CampaignSession:
	var rules := GameRules.load_files()
	var ai := AiPlayer.new(rules, _config)
	var humans: Array[String] = ["welfen", "wettiner", "staufer", "wittelsbacher"]
	var session := CampaignSession.create(rules, humans, seed_value)
	for house: HouseState in session.state.houses.values():
		house.personality = _config.personality_of(house.id)
		house.difficulty = difficulty
	session.set_meta("ai", ai)
	return session
