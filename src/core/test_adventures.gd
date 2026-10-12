extends GutTest
## Adventures in the campaign: one a round with a free leader, played live through the
## resolver or by the computer, and their results in the game.

var _rules: GameRules
var _state: GameState


func before_each() -> void:
	_rules = GameRules.load_files()
	_state = GameSetup.create(_rules.map, _rules.economy, 1)


func test_raiding_the_merchant_train_pays_its_cargo() -> void:
	_deal("staufer", "merchant_train", "SPT")
	_rules.adventure_resolver = func(setup: RefCounted) -> RefCounted:
		assert_true(setup is MerchantSetup)
		return _merchant(3, 105, false)
	assert_eq(_choose("staufer", "raid"), "")
	var staufer := _state.houses["staufer"]
	assert_eq(staufer.gold, 305.0)
	assert_eq(staufer.pending_prestige, -3.0, "the event's price")
	assert_eq(_state.crown.favour_of("KOE", "staufer"), 20.0, "Cologne frowns: 30 − 10")
	assert_eq(staufer.adventure_turn, _state.turn)
	assert_true(_state.events.drawn[0].won)


func test_a_captured_raider_forfeits_the_loot() -> void:
	_deal("staufer", "merchant_train", "SPT")
	_rules.adventure_resolver = func(_setup: RefCounted) -> RefCounted:
		return _merchant(0, 0, true)
	_choose("staufer", "raid")
	var staufer := _state.houses["staufer"]
	assert_eq(staufer.gold, 200.0)
	assert_eq(staufer.leader_captor, Adventures.MERCHANT_CAPTOR)
	assert_false(_state.events.drawn[0].won)


func test_the_computer_raids_when_nobody_plays_live() -> void:
	_deal("staufer", "merchant_train", "SPT")
	assert_eq(_choose("staufer", "raid"), "")
	var staufer := _state.houses["staufer"]
	assert_true(staufer.gold >= 200.0 or staufer.is_leader_captured())
	assert_eq(staufer.adventure_turn, _state.turn)


func test_the_raid_takes_the_leaders_strongest_companies() -> void:
	var army := _state.army(_state.houses["staufer"].leader_army)
	army.add_company("knights")
	var setup := Adventures.merchant_setup(_state, _rules, "staufer", "SPT")
	assert_eq(setup.companies, ["knights", "spearmen"] as Array[String])
	assert_eq(setup.blade, _state.houses["staufer"].blade)
	assert_eq(setup.raider_skill, _rules.map.campaign.adventure_auto_skill)


func test_one_adventure_a_round_and_only_with_a_free_leader() -> void:
	_deal("staufer", "merchant_train", "SPT")
	_state.houses["staufer"].adventure_turn = _state.turn
	assert_eq(_choose("staufer", "raid"), Adventures.ERROR_DONE)
	_state.houses["staufer"].adventure_turn = -1
	_state.houses["staufer"].leader_captor = "welfen"
	assert_eq(_choose("staufer", "raid"), Adventures.ERROR_LEADER_CAPTURED)
	assert_eq(_choose("staufer", "escort"), "", "escorting needs no leader")


func test_the_dialog_learns_the_setup_before_the_choice_runs() -> void:
	_deal("staufer", "merchant_train", "SPT")
	var raid := ChooseEventCommand.new(_rules, "staufer", "raid")
	assert_true(raid.adventure_setup(_state) is MerchantSetup)
	assert_null(ChooseEventCommand.new(_rules, "staufer", "escort").adventure_setup(_state))


func test_a_hosted_tournament_won_pays_prize_and_prestige() -> void:
	var welfen := _state.houses["welfen"]
	_state.provinces[welfen.home_province].buildings.append(_rules.economy.tournament_building)
	_state.active_index = _state.turn_order.find("welfen")
	_rules.adventure_resolver = func(setup: RefCounted) -> RefCounted:
		assert_eq((setup as JoustSetup).opponent, Adventures.VISITING_CHAMPION)
		return _joust(true)
	var host := HostTournamentCommand.new(_rules, "welfen")
	assert_true(host.adventure_setup(_state) is JoustSetup)
	assert_eq(host.execute(_state), "")
	assert_eq(welfen.gold, 200.0 - 80.0 + 100.0)
	assert_eq(welfen.pending_prestige, 10.0, "hosted +5, won +5")
	assert_eq(welfen.wins["lance"], 1)
	assert_eq(welfen.adventure_turn, _state.turn)


func test_an_invitation_takes_the_leader_to_his_favourite_elector() -> void:
	_deal("welfen", "tournament_invitation", "")
	_rules.adventure_resolver = func(setup: RefCounted) -> RefCounted:
		var joust := setup as JoustSetup
		assert_eq(joust.host_province, "KOE", "Cologne likes the Welfen best")
		assert_eq(joust.opponent, Adventures.ELECTOR_CHAMPION)
		return _joust(true)
	assert_eq(_choose("welfen", "attend"), "")
	assert_eq(_state.crown.favour_of("KOE", "welfen"), 60.0, "55 + 5")
	assert_eq(_state.houses["welfen"].gold, 300.0)
	assert_true(_state.events.drawn[0].won)


func test_three_wins_raise_a_skill() -> void:
	var welfen := _state.houses["welfen"]
	var lance := welfen.lance
	assert_false(welfen.add_win("lance", 3, 5))
	assert_false(welfen.add_win("lance", 3, 5))
	assert_true(welfen.add_win("lance", 3, 5))
	assert_eq(welfen.lance, lance + 1)
	assert_eq(welfen.wins["lance"], 0)
	welfen.blade = 5
	for i: int in 4:
		assert_false(welfen.add_win("blade", 3, 5), "no skill above the maximum")
	assert_eq(welfen.blade, 5)


func test_a_battle_won_with_the_leader_counts_for_leadership() -> void:
	var welfen := _state.armies_of("welfen")[0]
	var raiders := _state.add_army("staufer", welfen.province)
	raiders.add_company("levy")
	_rules.resolver = func(setup: BattleSetup) -> BattleResult:
		var result := BattleResult.new()
		result.attacker_won = false
		for i: int in setup.attacker.company_count():
			result.attacker_health.append(0.5)
		for i: int in setup.defender.company_count():
			result.defender_health.append(1.0)
		return result
	CampaignBattles.fight_army(_state, _rules, raiders, welfen, "")
	assert_eq(_state.houses["welfen"].wins.get("leadership", 0), 1)
	assert_eq(_state.houses["staufer"].wins.get("leadership", 0), 0)


func _joust(won: bool) -> JoustResult:
	var result := JoustResult.new()
	result.won = won
	return result


func _deal(house: String, event_id: String, province: String) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.EVENT
	_state.events.drawn.clear()
	_state.events.drawn.append(EventState.EventCard.create(event_id, house, province))
	_state.events.pending = 1


func _choose(house: String, choice: String) -> String:
	return ChooseEventCommand.new(_rules, house, choice).execute(_state)


func _merchant(wagons: int, taler: int, captured: bool) -> MerchantResult:
	var result := MerchantResult.new()
	result.wagons_total = 5
	result.wagons_stopped = wagons
	result.taler = taler
	result.leader_captured = captured
	return result
