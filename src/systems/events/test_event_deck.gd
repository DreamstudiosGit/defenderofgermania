extends GutTest
## Drawing event cards: one card per house and turn from the season's deck, none in the opening
## round, conditions (river, Thuringia, years, Bohemia's favour) and once-events firing once.

var _events: EventData
var _map: MapData
var _cfg: EconomyConfig
var _state: GameState


func before_all() -> void:
	_events = EventData.load_file()
	_map = MapData.load_file()
	_cfg = EconomyConfig.load_file()


func before_each() -> void:
	_state = GameSetup.create(_map, _cfg, 1)


func test_the_opening_round_has_no_cards() -> void:
	EventDeck.begin_turn(_state, _events, _map, _cfg)
	assert_true(_state.events.drawn.is_empty())
	assert_eq(_state.events.pending, 0)


func test_every_house_draws_one_card_of_the_season() -> void:
	for turn: int in range(1, 13):
		_state.turn = turn
		for index: int in _state.turn_order.size():
			_state.active_index = index
			EventDeck.begin_turn(_state, _events, _map, _cfg)
			var where := "turn %d, %s" % [turn, _state.active_house()]
			assert_eq(_state.events.drawn.size(), 1, where)
			for card: EventState.EventCard in _state.events.drawn:
				var event := _events.events[card.event]
				assert_true(event.seasons.is_empty() or _state.season() in event.seasons, card.event)
				assert_eq(card.house, _state.active_house())


func test_the_same_seed_draws_the_same_cards() -> void:
	var again := GameSetup.create(_map, _cfg, 1)
	for state: GameState in [_state, again]:
		state.turn = 5
		EventDeck.begin_turn(state, _events, _map, _cfg)
	assert_eq_deep(again.events.to_dict(), _state.events.to_dict())


func test_conditions_pick_the_houses_and_places() -> void:
	var flood := _events.events["flood"]
	_state.turn = 4
	assert_false(EventDeck.is_eligible(_state, _map, flood, "welfen"), "no river in the north")
	assert_eq(EventDeck.places(_state, _map, flood, "wittelsbacher"), ["BAY"] as Array[String])
	var wartburg := _events.events["wartburg_contest"]
	_state.turn = 5
	assert_true(EventDeck.is_eligible(_state, _map, wartburg, "wettiner"))
	assert_false(EventDeck.is_eligible(_state, _map, wartburg, "welfen"), "only Thuringia's lord")
	_state.turn = 4
	assert_false(EventDeck.is_eligible(_state, _map, wartburg, "wettiner"), "summer only")


func test_trouble_next_door_needs_a_border_province_that_is_not_home() -> void:
	var feud := _events.events["feud_letter"]
	assert_eq(EventDeck.places(_state, _map, feud, "welfen"), ["HOL"] as Array[String])
	_state.provinces["HOL"].owner = "staufer"
	assert_false(EventDeck.is_eligible(_state, _map, feud, "welfen"), "the home castle is spared")


func test_years_limit_the_zaehringer_and_the_crusade() -> void:
	var zaehringer := _events.events["zaehringer_candidacy"]
	var crusade := _events.events["crusade_call"]
	_state.turn = 11
	assert_true(EventDeck.is_eligible(_state, _map, zaehringer, "staufer"), "year 3")
	assert_false(EventDeck.is_eligible(_state, _map, crusade, "staufer"))
	_state.turn = 12
	assert_false(EventDeck.is_eligible(_state, _map, zaehringer, "staufer"), "year 4")
	assert_true(EventDeck.is_eligible(_state, _map, crusade, "staufer"))
	_state.events.fired.append("crusade_call")
	assert_false(EventDeck.is_eligible(_state, _map, crusade, "staufer"), "only once")


func test_bohemia_offers_its_crown_once_its_favour_reaches_fifty() -> void:
	_state.turn = 1
	_state.active_index = _state.turn_order.find("wettiner")
	EventDeck.begin_turn(_state, _events, _map, _cfg)
	assert_false(_has_card("bohemian_crown"), "favour 40 is not enough")
	_state.crown.set_favour("BOH", "wettiner", 50.0, 100.0)
	EventDeck.begin_turn(_state, _events, _map, _cfg)
	assert_true(_has_card("bohemian_crown"))
	assert_true("bohemian_crown" in _state.events.fired)
	assert_eq(_state.events.next_pending().event, "bohemian_crown", "it waits for a choice")
	EventDeck.begin_turn(_state, _events, _map, _cfg)
	assert_false(_has_card("bohemian_crown"), "never twice")


func test_disabled_events_are_never_drawn() -> void:
	var marriage := _events.events["marriage_offer"]
	_state.turn = 3
	assert_false(EventDeck.is_eligible(_state, _map, marriage, "welfen"))


func _has_card(event_id: String) -> bool:
	return _state.events.drawn.any(
		func(card: EventState.EventCard) -> bool: return card.event == event_id
	)
