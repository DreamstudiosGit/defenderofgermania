extends GutTest
## Adventures in the campaign: one a round with a free leader, played live through the
## resolver or by the computer, and their results in the game (merchant train so far).

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
