extends GutTest
## What the cards do, with the GDD numbers (table "Ereignisse"): grain, plague, flood, the
## court, the crown and the patrons. Battles and choices are tested in src/core.

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


func test_rats_eat_a_fifth_of_the_grain_a_tenth_with_a_granary() -> void:
	_fire("rat_plague", "welfen")
	assert_almost_eq(_state.houses["welfen"].grain, 240.0, 1e-9)
	_state.provinces["HOL"].buildings.append("granary")
	_fire("rat_plague", "welfen")
	assert_almost_eq(_state.houses["welfen"].grain, 216.0, 1e-9, "240 − 10 %")


func test_a_harsh_winter_makes_the_settlement_eat_a_quarter_more() -> void:
	_state.turn = 3
	var winter := GameState.Season.WINTER
	var before := EconomyTerm.sum(GrainBreakdown.grain_demand(_state, _cfg, "welfen", winter))
	var mild := GameState.from_dict(_state.to_dict())
	_fire("harsh_winter", "welfen")
	var terms := GrainBreakdown.grain_demand(_state, _cfg, "welfen", winter)
	assert_almost_eq(EconomyTerm.sum(terms), before * 1.25, 1e-9)
	assert_eq(terms[terms.size() - 1].label_key, "ECONOMY_TERM_EVENT_GRAIN")
	var stock := _state.houses["welfen"].grain
	EconomySettlement.settle(_state, _map, _cfg)
	EconomySettlement.settle(mild, _map, _cfg)
	var kept := mild.houses["welfen"].grain / (stock - before)
	var lost := mild.houses["welfen"].grain - _state.houses["welfen"].grain
	assert_almost_eq(lost, before * 0.25 * kept, 1e-6, "the settlement eats the extra quarter")
	EventRound.end_round(_state)
	assert_true(_state.events.grain_demand.is_empty(), "for one settlement only")


func test_a_flood_closes_the_province_and_spoils_its_harvest() -> void:
	_state.turn = 4
	_fire("flood", "wittelsbacher", "BAY")
	assert_true(_state.events.is_blocked("BAY", 4))
	assert_false(_state.events.is_blocked("BAY", 5), "for one round")
	var harvest := GrainBreakdown.harvest(_state, _map, _cfg, "wittelsbacher")
	_state.events.harvest.clear()
	var dry := GrainBreakdown.harvest(_state, _map, _cfg, "wittelsbacher")
	assert_almost_eq(harvest[1].value, dry[1].value * 0.8, 1e-9, "Bavaria −20 %")
	assert_almost_eq(harvest[0].value, dry[0].value, 1e-9, "Nuremberg dry")


func test_the_plague_strikes_a_province_and_its_neighbours() -> void:
	var koe := _state.provinces["KOE"]
	var aac := _state.provinces["AAC"]
	var population := [koe.population, aac.population]
	koe.satisfaction = 50.0
	aac.satisfaction = 50.0
	aac.buildings.append("monastery")
	_fire("plague", "", "KOE")
	assert_almost_eq(koe.population, population[0] * 0.9, 1e-9)
	assert_almost_eq(koe.satisfaction, 40.0, 1e-9)
	assert_almost_eq(aac.population, population[1] * 0.95, 1e-9, "the monastery halves it")
	assert_almost_eq(aac.satisfaction, 45.0, 1e-9)


func test_court_choices_cost_and_pay_as_the_gdd_says() -> void:
	var home := _state.provinces["BSW"]
	var satisfaction := home.satisfaction
	_choose("jugglers", "accept", "welfen")
	assert_almost_eq(home.satisfaction, satisfaction + 3.0, 1e-9)
	_choose("wartburg_contest", "host", "wettiner", "THU")
	assert_eq(_state.houses["wettiner"].pending_prestige, 8.0)
	_choose("robber_knights", "ignore", "welfen", "HOL")
	assert_almost_eq(_state.provinces["HOL"].satisfaction, _cfg.start_satisfaction - 5.0, 1e-9)
	_choose("hostage", "abandon", "staufer")
	assert_eq(_state.houses["staufer"].pending_prestige, -5.0)


func test_escorting_merchants_pleases_the_trade_cities() -> void:
	_choose("merchant_train", "escort", "staufer", "SPT")
	var staufer := _state.houses["staufer"]
	assert_eq([staufer.gold, staufer.pending_prestige], [220.0, 2.0])
	assert_eq(_state.crown.favour_of("KOE", "staufer"), 35.0)
	assert_eq(_state.crown.favour_of("BBT", "staufer"), 35.0)


func test_adventures_wait_for_their_milestone() -> void:
	for pair: Array in [["tournament_invitation", "attend"], ["hostage", "raid"]]:
		var choice := _events.events[pair[0]].choice(pair[1])
		var card := EventState.EventCard.create(pair[0], "welfen", "")
		assert_eq(EventEffects.choice_error(_state, card, choice), EventEffects.ERROR_ADVENTURE_LATER)
	var raid := _events.events["merchant_train"].choice("raid")
	var card := EventState.EventCard.create("merchant_train", "staufer", "SPT")
	assert_eq(EventEffects.choice_error(_state, card, raid), EventEffects.ERROR_ADVENTURE_LATER)


func test_bohemia_promises_its_vote_for_prestige() -> void:
	_choose("bohemian_crown", "promise", "wittelsbacher")
	assert_eq(CrownRules.votes(_state, _map)["BOH"], "wittelsbacher")
	assert_eq(_state.houses["wittelsbacher"].pending_prestige, -10.0)


func test_the_zaehringer_sells_breisgau_while_it_is_neutral() -> void:
	var buy := _events.events["zaehringer_candidacy"].choice("buy")
	var card := EventState.EventCard.create("zaehringer_candidacy", "staufer", "")
	assert_eq(EventEffects.choice_error(_state, card, buy), Command.ERROR_NOT_ENOUGH_GOLD)
	_state.houses["staufer"].gold = 400.0
	assert_eq(EventEffects.choice_error(_state, card, buy), "")
	_choose("zaehringer_candidacy", "buy", "staufer")
	assert_eq(_state.provinces["BRG"].owner, "staufer")
	assert_eq(_state.houses["staufer"].gold, 0.0)
	_state.houses["staufer"].gold = 400.0
	assert_eq(EventEffects.choice_error(_state, card, buy), EventEffects.ERROR_TARGET_GONE)


func test_crusaders_leave_for_eight_rounds_and_come_home() -> void:
	var army := _state.armies_of("staufer")[0]
	var send := _events.events["crusade_call"].choice("send")
	var card := EventState.EventCard.create("crusade_call", "staufer", "")
	assert_eq(EventEffects.choice_error(_state, card, send), EventEffects.ERROR_NO_UNITS)
	army.add_company("knights")
	army.add_company("knights")
	_state.turn = 12
	_choose("crusade_call", "send", "staufer")
	assert_eq(army.units.count("knights"), 0)
	assert_eq(_state.houses["staufer"].pending_prestige, 10.0)
	for id: String in ["KOE", "MAI", "TRI"]:
		assert_eq(_state.crown.favour_of(id, "staufer"), 40.0 if id != "MAI" else 55.0, id)
	_state.turn = 19
	EventRound.start_round(_state, _events, _map, _cfg)
	assert_eq(_state.armies_of("staufer").size(), 1, "still away")
	_state.turn = 20
	EventRound.start_round(_state, _events, _map, _cfg)
	var home := _state.armies_in(_state.houses["staufer"].home_province)
	assert_eq(home.back().units, ["knights", "knights"] as Array[String], "back at the home castle")


func test_the_papal_legate_rewards_the_most_pious_and_threatens_the_least() -> void:
	_state.crown.set_favour("KOE", "welfen", 90.0, 100.0)
	for house: String in ["staufer", "wettiner"]:
		_state.crown.set_favour("TRI", house, 40.0, 100.0)
	_state.crown.set_favour("MAI", "wittelsbacher", 0.0, 100.0)
	var legate := _events.events["papal_legate"]
	legate.effects[1].amount = 1.0
	_fire("papal_legate", "")
	legate.effects[1].amount = 0.25
	assert_eq(_state.crown.favour_of("TRI", "welfen"), 40.0, "+10 with every church elector")
	assert_true(_state.houses["wittelsbacher"].is_banned)
	assert_false(_state.houses["welfen"].is_banned)


func test_nobody_is_singled_out_on_a_tie() -> void:
	var legate := _events.events["papal_legate"]
	var card := EventState.EventCard.create("papal_legate", "", "")
	assert_true(EventEffects.houses(_state, _events, card, legate.effects[1]).size() <= 1)
	for house: String in _state.houses:
		for id: String in ["KOE", "MAI", "TRI"]:
			_state.crown.set_favour(id, house, 30.0, 100.0)
	assert_true(EventEffects.houses(_state, _events, card, legate.effects[0]).is_empty())


func test_the_lionheart_dies_in_the_spring_of_the_second_year() -> void:
	_state.turn = 3
	EventRound.start_round(_state, _events, _map, _cfg)
	assert_eq(_state.crown.patron_strength["england"], 1.0)
	_state.turn = 4
	EventRound.start_round(_state, _events, _map, _cfg)
	assert_eq(_state.crown.patron_strength["england"], 0.75)
	assert_eq(_state.crown.patron_strength["france"], 1.0)
	assert_true(_state.events.news.any(
		func(card: EventState.EventCard) -> bool: return card.event == "death_of_lionheart"
	))


func test_an_extreme_harvest_makes_the_news_in_winter() -> void:
	_state.turn = 3
	_state.weather = {"north": 0.6, "middle": 1.0, "south": 1.3} as Dictionary[String, float]
	EventRound.start_round(_state, _events, _map, _cfg)
	var regions: Array[String] = []
	for card: EventState.EventCard in _state.events.news:
		if card.event == "harvest_extreme":
			regions.append(card.region)
	assert_eq(regions, ["north", "south"] as Array[String])


func _fire(event_id: String, house: String, province: String = "") -> void:
	var card := EventState.EventCard.create(event_id, house, province)
	EventEffects.apply(_state, _events, _map, _cfg, card, _events.events[event_id].effects)


func _choose(event_id: String, choice_id: String, house: String, province: String = "") -> void:
	var card := EventState.EventCard.create(event_id, house, province)
	var choice := _events.events[event_id].choice(choice_id)
	assert_eq(EventEffects.choice_error(_state, card, choice), "", "%s.%s" % [event_id, choice_id])
	_state.houses[house].gold -= choice.cost
	EventEffects.apply(_state, _events, _map, _cfg, card, choice.effects)
