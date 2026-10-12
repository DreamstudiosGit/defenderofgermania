extends GutTest
## Answering event cards: the house stays in its event phase until every card is answered,
## ending the phase takes the defaults, and robber knights and feuds are fought out.

var _rules: GameRules
var _state: GameState


func before_each() -> void:
	_rules = GameRules.load_files()
	_state = GameSetup.create(_rules.map, _rules.economy, 1)


func test_the_house_answers_its_cards_then_administrates() -> void:
	_deal("welfen", [["jugglers", ""], ["hostage", ""]])
	assert_eq(_choose("welfen", "accept"), "")
	assert_eq(_state.phase, GameState.Phase.EVENT, "the second card still waits")
	assert_eq(_state.houses["welfen"].gold, 180.0)
	assert_eq(_choose("welfen", "ransom"), "")
	assert_eq(_state.houses["welfen"].gold, 60.0)
	assert_eq(_state.phase, GameState.Phase.ADMINISTRATION)
	assert_eq(_choose("welfen", "accept"), ChooseEventCommand.ERROR_WRONG_PHASE)


func test_wrong_or_unaffordable_choices_are_refused() -> void:
	_deal("welfen", [["hostage", ""]])
	assert_eq(_choose("welfen", "pray"), ChooseEventCommand.ERROR_UNKNOWN_CHOICE)
	assert_eq(_choose("welfen", "raid"), EventEffects.ERROR_ADVENTURE_LATER)
	_state.houses["welfen"].gold = 119.0
	assert_eq(_choose("welfen", "ransom"), Command.ERROR_NOT_ENOUGH_GOLD)
	assert_eq(_choose("staufer", "abandon"), Command.ERROR_NOT_ACTIVE)


func test_ending_the_phase_takes_the_defaults() -> void:
	_deal("welfen", [["jugglers", ""], ["feud_letter", "HOL"]])
	assert_eq(EndPhaseCommand.new(_rules, "welfen").execute(_state), "")
	assert_eq(_state.phase, GameState.Phase.ADMINISTRATION)
	assert_eq(_state.houses["welfen"].gold, 120.0, "declined the jugglers, paid the 80 T atonement")
	assert_eq(_state.events.drawn[1].choice, "atone")


func test_a_poor_house_fights_the_feud_it_cannot_atone() -> void:
	_deal("welfen", [["feud_letter", "HOL"]])
	_state.houses["welfen"].gold = 10.0
	_rules.resolver = func(setup: BattleSetup) -> BattleResult: return _result(setup, false)
	ChooseEventCommand.resolve_by_default(_state, _rules)
	assert_eq(_state.events.drawn[0].choice, "fight")
	assert_true(_state.events.drawn[0].won, "the garrison held")
	assert_eq(_state.provinces["HOL"].owner, "welfen")


func test_a_lost_feud_hands_the_province_to_a_neutral_count() -> void:
	_deal("welfen", [["feud_letter", "HOL"]])
	var defender := _state.add_army("welfen", "HOL")
	defender.add_company("levy")
	var sizes: Array[int] = []
	_rules.resolver = func(setup: BattleSetup) -> BattleResult:
		sizes.append(setup.attacker.company_count())
		return _result(setup, true)
	assert_eq(_choose("welfen", "fight"), "")
	assert_eq(sizes, [4] as Array[int], "four companies of the count")
	assert_eq(_state.provinces["HOL"].owner, "neutral")
	assert_false(_state.events.drawn[0].won)


func test_hunting_robber_knights_pays_on_victory() -> void:
	_deal("welfen", [["robber_knights", "HOL"]])
	var army := _state.armies_of("welfen")[0]
	_rules.resolver = func(setup: BattleSetup) -> BattleResult:
		assert_eq(setup.defender.company_count(), 3, "three companies of levy")
		return _result(setup, true)
	assert_eq(_choose("welfen", "hunt"), "")
	var welfen := _state.houses["welfen"]
	assert_eq([welfen.gold, welfen.pending_prestige], [250.0, 3.0], "50 T and +3, no battle bonus")
	assert_not_null(_state.army(army.id))


func test_the_hunt_needs_an_army_close_by() -> void:
	_deal("welfen", [["robber_knights", "HOL"]])
	_state.armies_of("welfen")[0].province = "MAG"
	assert_eq(_choose("welfen", "hunt"), EventBattles.ERROR_NO_ARMY)
	assert_eq(_choose("welfen", "ignore"), "")


func test_a_flooded_province_takes_no_army_this_round() -> void:
	_state.events.blocked_until["HOL"] = _state.turn + 1
	_state.phase = GameState.Phase.CAMPAIGN
	_state.active_index = _state.turn_order.find("welfen")
	var army := _state.armies_of("welfen")[0]
	army.moves_left = 1
	var move := MoveArmyCommand.new(_rules, "welfen", army.id, "HOL")
	assert_eq(move.execute(_state), MoveArmyCommand.ERROR_FLOODED)
	_state.turn += 1
	assert_eq(move.validate(_state), "")


func test_a_whole_game_round_draws_cards_for_every_house() -> void:
	_state.turn = 0
	var houses_with_cards: Array[String] = []
	while _state.turn < 2:
		if not _state.events.drawn.is_empty() and _state.active_house() not in houses_with_cards:
			houses_with_cards.append(_state.active_house())
		EndPhaseCommand.new(_rules, _state.active_house()).execute(_state)
	houses_with_cards.sort()
	assert_eq(houses_with_cards, ["staufer", "welfen", "wettiner", "wittelsbacher"] as Array[String])


func _deal(house: String, cards: Array) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.EVENT
	_state.events.drawn.clear()
	for entry: Array in cards:
		_state.events.drawn.append(EventState.EventCard.create(entry[0], house, entry[1]))
	_state.events.pending = cards.size()


func _choose(house: String, choice: String) -> String:
	return ChooseEventCommand.new(_rules, house, choice).execute(_state)


func _result(setup: BattleSetup, attacker_wins: bool) -> BattleResult:
	var result := BattleResult.new()
	result.attacker_won = attacker_wins
	for i: int in setup.attacker.company_count():
		result.attacker_health.append(1.0)
	for i: int in setup.defender.company_count():
		result.defender_health.append(1.0)
	return result
