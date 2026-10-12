extends GutTest
## The coronation rule along all four rows of the GDD table (milestone M5 acceptance): true or
## forged regalia at Aachen or Mainz need 4, 5, 5 or 6 votes; one vote fewer is not enough.
## Plus the electors' votes: threshold, ties, the ban, occupation and promises.

const WINTER_TURN := 3
const ELECTORS: Array[String] = ["KOE", "TRI", "PFA", "SXW", "BRB", "BOH", "MAI"]

var _rules: GameRules
var _map: MapData
var _state: GameState


func before_all() -> void:
	_rules = GameRules.load_files()
	_map = _rules.map


func before_each() -> void:
	_state = GameSetup.create(_map, _rules.economy, 1)
	_state.turn = WINTER_TURN


func test_true_regalia_at_aachen_need_four_votes() -> void:
	_give("welfen", ["SPT", "AAC"])
	_win_votes("welfen", ["KOE", "TRI", "PFA"])
	assert_eq(_crown("welfen"), CrownRules.ERROR_NOT_ENOUGH_VOTES, "three votes are too few")
	_win_votes("welfen", ["BRB"])
	_assert_crowned("welfen", "coronation_site")


func test_forged_regalia_at_aachen_need_five_votes() -> void:
	_give("welfen", ["AAC"])
	_state.crown.forged_regalia.append("welfen")
	_win_votes("welfen", ["KOE", "TRI", "PFA", "BRB"])
	assert_eq(_crown("welfen"), CrownRules.ERROR_NOT_ENOUGH_VOTES, "four votes are too few")
	_win_votes("welfen", ["SXW"])
	_assert_crowned("welfen", "coronation_site")


func test_true_regalia_at_mainz_need_five_votes() -> void:
	# Holding Mainz forces its archbishop's vote and makes him crown.
	_give("staufer", ["MAI"])
	_win_votes("staufer", ["TRI", "PFA", "SXW"])
	assert_eq(_crown("staufer"), CrownRules.ERROR_NOT_ENOUGH_VOTES, "four votes are too few")
	_win_votes("staufer", ["BRB"])
	_assert_crowned("staufer", "emergency_coronation_site")


func test_forged_regalia_at_mainz_need_six_votes() -> void:
	_give("wittelsbacher", ["MAI"])
	_state.crown.forged_regalia.append("wittelsbacher")
	_win_votes("wittelsbacher", ["KOE", "TRI", "PFA", "SXW"])
	assert_eq(_crown("wittelsbacher"), CrownRules.ERROR_NOT_ENOUGH_VOTES, "five are too few")
	_win_votes("wittelsbacher", ["BOH"])
	_assert_crowned("wittelsbacher", "emergency_coronation_site")


func test_the_cheapest_row_wins_when_several_are_open() -> void:
	_give("staufer", ["AAC", "MAI"])
	_state.crown.forged_regalia.append("staufer")
	_win_votes("staufer", ["KOE", "TRI", "PFA"])
	assert_eq(CrownRules.votes_needed(_state, _map, "staufer"), 4, "true regalia at Aachen")
	_assert_crowned("staufer", "coronation_site")


func test_missing_pillars_are_named_in_order() -> void:
	assert_eq(_crown("welfen"), CrownRules.ERROR_NO_REGALIA)
	_state.crown.forged_regalia.append("welfen")
	assert_eq(_crown("welfen"), CrownRules.ERROR_NO_SITE)
	_give("welfen", ["AAC"])
	_state.crown.set_favour("KOE", "welfen", 49.0, 100.0)
	assert_eq(_crown("welfen"), CrownRules.ERROR_NO_ARCHBISHOP, "Cologne's favour below 50")
	_state.crown.set_favour("KOE", "welfen", 50.0, 100.0)
	assert_eq(_crown("welfen"), CrownRules.ERROR_NOT_ENOUGH_VOTES)


func test_coronations_happen_only_in_winter() -> void:
	_give("welfen", ["SPT", "AAC"])
	_win_votes("welfen", ["KOE", "TRI", "PFA", "BRB"])
	_state.turn = WINTER_TURN + 1
	assert_eq(_crown("welfen"), CoronationCommand.ERROR_NOT_WINTER)
	assert_false(_state.is_over())


func test_an_elector_votes_for_the_highest_favour_from_sixty() -> void:
	_state.crown.set_favour("TRI", "welfen", 59.9, 100.0)
	assert_eq(CrownRules.votes(_state, _map)["TRI"], CrownRules.ABSTAIN, "below the threshold")
	_state.crown.set_favour("TRI", "welfen", 60.0, 100.0)
	assert_eq(CrownRules.votes(_state, _map)["TRI"], "welfen")
	_state.crown.set_favour("TRI", "staufer", 60.0, 100.0)
	assert_eq(CrownRules.votes(_state, _map)["TRI"], CrownRules.ABSTAIN, "a tie abstains")
	_state.crown.set_favour("TRI", "staufer", 61.0, 100.0)
	assert_eq(CrownRules.votes(_state, _map)["TRI"], "staufer")


func test_church_electors_never_vote_for_a_banned_house() -> void:
	_win_votes("welfen", ["KOE", "PFA"])
	_state.houses["welfen"].is_banned = true
	var votes := CrownRules.votes(_state, _map)
	assert_eq(votes["KOE"], CrownRules.ABSTAIN, "the archbishop of Cologne refuses")
	assert_eq(votes["PFA"], "welfen", "the count palatine does not care")


func test_occupied_and_promised_votes_are_forced() -> void:
	_give("wettiner", ["TRI"])
	_state.crown.promised_votes["BOH"] = "wittelsbacher"
	_win_votes("welfen", ["BOH"])
	var votes := CrownRules.votes(_state, _map)
	assert_eq(votes["TRI"], "wettiner", "the occupier's vote")
	assert_eq(votes["BOH"], "wittelsbacher", "the promise beats favour")
	assert_eq(CrownRules.vote_count(_state, _map, "wettiner"), 1)


func _give(house: String, provinces: Array[String]) -> void:
	for id: String in provinces:
		_state.provinces[id].owner = house


func _win_votes(house: String, electors: Array[String]) -> void:
	for id: String in electors:
		assert_true(id in ELECTORS)
		_state.crown.set_favour(id, house, 60.0, 100.0)


func _crown(house: String) -> String:
	_state.active_index = _state.turn_order.find(house)
	return CoronationCommand.new(_map, house).execute(_state)


func _assert_crowned(house: String, site: String) -> void:
	assert_eq(_crown(house), "")
	assert_eq(_state.winner, house)
	assert_eq(_state.crown.crowned_at, site)
	assert_true(_state.is_over())
