extends GutTest

var _cfg: EconomyConfig
var _state: GameState


func before_each() -> void:
	_cfg = EconomyConfig.load_file()
	_state = GameSetup.create(MapData.load_file(), _cfg, 1)


func test_valid_tax_rate_applies() -> void:
	_activate("welfen")
	assert_eq(SetTaxRateCommand.new(_cfg, "welfen", 25).execute(_state), "")
	assert_eq(_state.houses["welfen"].tax_rate, 25)


func test_invalid_tax_rate_is_rejected_without_change() -> void:
	_activate("welfen")
	var error := SetTaxRateCommand.new(_cfg, "welfen", 17).execute(_state)
	assert_eq(error, SetTaxRateCommand.ERROR_INVALID_TAX_RATE)
	assert_eq(_state.houses["welfen"].tax_rate, _cfg.start_tax_rate)


func test_unknown_house_is_rejected() -> void:
	var error := SetTaxRateCommand.new(_cfg, "habsburg", 10).execute(_state)
	assert_eq(error, Command.ERROR_UNKNOWN_HOUSE)


func test_valid_ration_applies() -> void:
	_activate("staufer")
	assert_eq(SetRationCommand.new(_cfg, "staufer", 2).execute(_state), "")
	assert_eq(_state.houses["staufer"].ration, 2)


func test_invalid_ration_is_rejected_without_change() -> void:
	_activate("staufer")
	var error := SetRationCommand.new(_cfg, "staufer", 7).execute(_state)
	assert_eq(error, SetRationCommand.ERROR_INVALID_RATION)
	assert_eq(_state.houses["staufer"].ration, _cfg.start_ration)


func test_only_the_active_house_may_act() -> void:
	_activate("welfen")
	var error := SetTaxRateCommand.new(_cfg, "staufer", 25).execute(_state)
	assert_eq(error, Command.ERROR_NOT_ACTIVE)
	assert_eq(_state.houses["staufer"].tax_rate, _cfg.start_tax_rate)


func test_administration_commands_are_rejected_in_the_campaign_phase() -> void:
	_activate("welfen")
	_state.phase = GameState.Phase.CAMPAIGN
	var error := SetRationCommand.new(_cfg, "welfen", 4).execute(_state)
	assert_eq(error, Command.ERROR_WRONG_PHASE)


func test_commands_are_rejected_after_the_game_ended() -> void:
	_activate("welfen")
	_state.phase = GameState.Phase.GAME_OVER
	assert_eq(SetRationCommand.new(_cfg, "welfen", 4).execute(_state), Command.ERROR_GAME_OVER)


func test_error_keys_have_texts() -> void:
	var texts := FileAccess.get_file_as_string("res://data/i18n/texts.csv")
	for key: String in [
		Command.ERROR_UNKNOWN_HOUSE,
		SetTaxRateCommand.ERROR_INVALID_TAX_RATE,
		SetRationCommand.ERROR_INVALID_RATION,
		BuildCommand.ERROR_UNKNOWN_BUILDING,
		BuildCommand.ERROR_ALREADY_BUILT,
		BuildCommand.ERROR_NO_SLOT,
		BuildCommand.ERROR_PREREQUISITE,
		UpgradeCastleCommand.ERROR_MAX_LEVEL,
		UpgradeCastleCommand.ERROR_UNDER_CONSTRUCTION,
		BuyDecorationCommand.ERROR_UNKNOWN_DECORATION,
		BuyDecorationCommand.ERROR_ALREADY_OWNED,
		BuyDecorationCommand.ERROR_LIMIT,
		RecruitCommand.ERROR_UNKNOWN_UNIT,
		RecruitCommand.ERROR_NO_CASTLE,
		RecruitCommand.ERROR_UNIT_LOCKED,
		RecruitCommand.ERROR_RECRUIT_LIMIT,
		RecruitCommand.ERROR_ENEMY_PRESENT,
		RecruitCommand.ERROR_NO_ARMY_ROOM,
		TradeGrainCommand.ERROR_INVALID_AMOUNT,
		TradeGrainCommand.ERROR_NOT_ENOUGH_GRAIN,
		PayRansomCommand.ERROR_NOT_CAPTURED,
	]:
		assert_string_contains(texts, "\n%s," % key)


func _activate(house: String) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.ADMINISTRATION
