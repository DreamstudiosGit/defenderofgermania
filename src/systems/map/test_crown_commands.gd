extends GutTest
## Court actions of the administration phase: gifts, homage, penance, patron cards, forged
## regalia and tournaments, with the GDD numbers.

var _rules: GameRules
var _map: MapData
var _state: GameState


func before_all() -> void:
	_rules = GameRules.load_files()
	_map = _rules.map


func before_each() -> void:
	_state = GameSetup.create(_map, _rules.economy, 1)


func test_gifts_buy_favour_that_wanes_within_a_year() -> void:
	assert_eq(_run(GiftCommand.new(_map, "welfen", "KOE")), "")
	assert_eq(_state.houses["welfen"].gold, 150.0)
	assert_eq(_state.crown.favour_of("KOE", "welfen"), 60.0, "55 + 5")
	_run(GiftCommand.new(_map, "welfen", "KOE"))
	assert_eq(_state.crown.favour_of("KOE", "welfen"), 64.0, "the second gift brings 4")
	_state.crown.gifts.clear()
	_run(GiftCommand.new(_map, "welfen", "KOE"))
	assert_eq(_state.crown.favour_of("KOE", "welfen"), 69.0, "a new year starts at 5 again")


func test_wittelsbacher_gifts_are_cheaper_and_count_more() -> void:
	_run(GiftCommand.new(_map, "wittelsbacher", "BOH"))
	assert_eq(_state.houses["wittelsbacher"].gold, 200.0 - 37.5)
	assert_eq(_state.crown.favour_of("BOH", "wittelsbacher"), 47.5, "40 + 7.5")


func test_only_lords_with_a_favour_list_take_gifts() -> void:
	assert_eq(_run(GiftCommand.new(_map, "welfen", "SPT")), GiftCommand.ERROR_NO_FAVOUR_LIST)
	assert_eq(_run(GiftCommand.new(_map, "welfen", "OSN")), GiftCommand.ERROR_NO_FAVOUR_LIST)
	_state.houses["welfen"].gold = 49.0
	assert_eq(_run(GiftCommand.new(_map, "welfen", "KOE")), Command.ERROR_NOT_ENOUGH_GOLD)


func test_a_neutral_lord_pays_homage_from_favour_eighty() -> void:
	_state.crown.set_favour("ELS", "staufer", 79.9, 100.0)
	assert_eq(_run(HomageCommand.new(_map, "staufer", "ELS")), HomageCommand.ERROR_FAVOUR)
	_state.crown.set_favour("ELS", "staufer", 80.0, 100.0)
	assert_eq(_run(HomageCommand.new(_map, "staufer", "ELS")), "")
	assert_eq(_state.provinces["ELS"].owner, "staufer")
	assert_eq(_state.provinces["ELS"].occupied_rounds, 0, "homage is no occupation")
	assert_eq(_state.houses["staufer"].gold, 100.0)


func test_electors_and_church_land_never_pay_homage() -> void:
	for id: String in ["KOE", "OSN", "SPT"]:
		_state.crown.set_favour(id, "welfen", 100.0, 100.0)
		assert_eq(_run(HomageCommand.new(_map, "welfen", id)), HomageCommand.ERROR_NOT_NEUTRAL, id)


func test_penance_lifts_the_ban_and_halts_the_campaign() -> void:
	assert_eq(_run(PenanceCommand.new(_map, "welfen")), PenanceCommand.ERROR_NOT_BANNED)
	_state.houses["welfen"].is_banned = true
	assert_eq(_run(PenanceCommand.new(_map, "welfen")), "")
	var welfen := _state.houses["welfen"]
	assert_false(welfen.is_banned)
	assert_eq([welfen.gold, welfen.prestige], [50.0, 10.0])
	_state.phase = GameState.Phase.CAMPAIGN
	var army := _state.armies_of("welfen")[0]
	var move := MoveArmyCommand.new(_rules, "welfen", army.id, "HOL")
	army.moves_left = 1
	assert_eq(_run(move), MoveArmyCommand.ERROR_PENANCE)
	_state.turn += 1
	assert_eq(move.validate(_state), "", "the next round the armies march again")


func test_the_chapel_halves_the_penance() -> void:
	_state.provinces[_state.houses["welfen"].home_province].castle_level = 4
	_state.houses["welfen"].is_banned = true
	_run(PenanceCommand.new(_map, "welfen"))
	assert_eq(_state.houses["welfen"].gold, 125.0)


func test_patron_cards_give_silver_mercenaries_or_an_embassy_once_a_round() -> void:
	assert_eq(_run(PlayPatronCommand.new(_map, "welfen", PlayPatronCommand.SILVER)), "")
	assert_eq(_state.houses["welfen"].gold, 400.0)
	var again := PlayPatronCommand.new(_map, "welfen", PlayPatronCommand.MERCENARIES)
	assert_eq(_run(again), PlayPatronCommand.ERROR_PLAYED)
	CrownSettlement.settle(_state, _map)
	assert_eq(_run(again), "")
	assert_eq(_state.crown.mercenaries["welfen"], 4)
	CrownSettlement.settle(_state, _map)
	var embassy := PlayPatronCommand.new(_map, "welfen", PlayPatronCommand.EMBASSY, "TRI")
	var before := _state.crown.favour_of("TRI", "welfen")
	assert_eq(_run(embassy), "")
	assert_eq(_state.crown.favour_of("TRI", "welfen"), before + 15.0)
	CrownSettlement.settle(_state, _map)
	assert_eq(_run(PlayPatronCommand.new(_map, "welfen", PlayPatronCommand.SILVER)), (
		PlayPatronCommand.ERROR_NO_CARDS
	), "three cards per game")


func test_an_embassy_goes_only_to_an_elector() -> void:
	var embassy := PlayPatronCommand.new(_map, "staufer", PlayPatronCommand.EMBASSY, "ELS")
	assert_eq(_run(embassy), PlayPatronCommand.ERROR_NOT_ELECTOR)
	assert_eq(_run(PlayPatronCommand.new(_map, "staufer", "gold")), (
		PlayPatronCommand.ERROR_UNKNOWN_CARD
	))


func test_a_weakened_patron_gives_three_quarters() -> void:
	_state.crown.patron_strength["england"] = 0.75
	_run(PlayPatronCommand.new(_map, "welfen", PlayPatronCommand.MERCENARIES))
	assert_eq(_state.crown.mercenaries["welfen"], 3)
	_run(PlayPatronCommand.new(_map, "staufer", PlayPatronCommand.SILVER))
	assert_eq(_state.houses["staufer"].gold, 400.0, "France keeps full strength")


func test_forged_regalia_need_castle_three_and_two_rounds() -> void:
	_state.houses["wettiner"].gold = 500.0
	var forge := ForgeRegaliaCommand.new(_map, "wettiner")
	assert_eq(_run(forge), ForgeRegaliaCommand.ERROR_CASTLE)
	_state.provinces[_state.houses["wettiner"].home_province].castle_level = 3
	assert_eq(_run(forge), "")
	assert_eq(_state.houses["wettiner"].gold, 200.0)
	assert_eq(_run(forge), ForgeRegaliaCommand.ERROR_FORGED, "one forgery is enough")
	CrownSettlement.settle(_state, _map)
	assert_false("wettiner" in _state.crown.forged_regalia)
	CrownSettlement.settle(_state, _map)
	assert_true("wettiner" in _state.crown.forged_regalia)
	assert_eq(CrownRules.regalia(_state, "wettiner"), ["forged"] as Array[String])


func test_a_tournament_brings_prestige_and_every_electors_favour() -> void:
	_rules.adventure_resolver = func(_setup: RefCounted) -> RefCounted: return JoustResult.new()
	var host := HostTournamentCommand.new(_rules, "wittelsbacher")
	assert_eq(_run(host), HostTournamentCommand.ERROR_NO_GROUND)
	var home := _state.provinces[_state.houses["wittelsbacher"].home_province]
	home.buildings.append(_rules.economy.tournament_building)
	assert_eq(_run(host), "")
	var wittelsbacher := _state.houses["wittelsbacher"]
	assert_eq([wittelsbacher.gold, wittelsbacher.pending_prestige], [120.0, 5.0])
	assert_eq(_state.crown.favour_of("BOH", "wittelsbacher"), 44.5, "40 + 3 × 1.5")
	assert_eq(_state.crown.favour_of("KOE", "wittelsbacher"), 34.5)
	assert_eq(_state.crown.favour_of("ELS", "wittelsbacher"), 30.0, "only electors")
	assert_eq(_run(host), HostTournamentCommand.ERROR_HOSTED)
	_state.turn = 2
	assert_eq(_run(host), HostTournamentCommand.ERROR_SEASON, "no tournaments in autumn")
	_rules.adventure_resolver = Callable()


func _run(command: Command) -> String:
	_state.active_index = _state.turn_order.find(command.house)
	return command.execute(_state)
