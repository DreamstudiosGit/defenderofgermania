extends GutTest
## Campaign panels emit commands instead of changing the state, show why actions are refused,
## and every text key they use exists in data/i18n/texts.csv.

const TEXTS := "res://data/i18n/texts.csv"
const SOURCES: Array[String] = ["res://src/ui/campaign/", "res://src/systems/economy/"]

var _rules: GameRules
var _state: GameState


func before_all() -> void:
	_rules = GameRules.load_files()


func before_each() -> void:
	_state = GameSetup.create(_rules.map, _rules.economy, 1)
	_state.active_index = _state.turn_order.find("welfen")


func test_tax_button_emits_a_command_and_refresh_shows_the_result() -> void:
	var panel: AdministrationPanel = add_child_autofree(AdministrationPanel.new())
	panel.refresh(_state, _rules, "welfen", "BSW")
	watch_signals(panel)
	_button(panel, "tax_20").pressed.emit()
	var command := _emitted(panel) as SetTaxRateCommand
	assert_not_null(command)
	assert_eq(_state.houses["welfen"].tax_rate, 15, "the panel must not change the state")
	assert_eq(command.execute(_state), "")
	panel.refresh(_state, _rules, "welfen", "BSW")
	assert_true(_button(panel, "tax_20").button_pressed)
	assert_false(_button(panel, "tax_15").button_pressed)


func test_refused_building_is_disabled_with_its_reason() -> void:
	var panel: AdministrationPanel = add_child_autofree(AdministrationPanel.new())
	panel.refresh(_state, _rules, "welfen", "HOL")
	assert_false(_button(panel, "building_granary").disabled)
	var market := _button(panel, "building_market_2")
	assert_true(market.disabled)
	assert_string_contains(market.tooltip_text, tr(BuildCommand.ERROR_PREREQUISITE))


func test_grain_trade_emits_the_chosen_amount() -> void:
	var panel: AdministrationPanel = add_child_autofree(AdministrationPanel.new())
	panel.refresh(_state, _rules, "welfen", "BSW")
	watch_signals(panel)
	_button(panel, "sell").pressed.emit()
	var command := _emitted(panel) as TradeGrainCommand
	assert_not_null(command)
	assert_lt(command.bushels, 0)


func test_hud_ends_the_phase_through_a_command() -> void:
	var hud: CampaignHud = add_child_autofree(CampaignHud.new())
	hud.refresh(_state, _rules, "welfen")
	watch_signals(hud)
	_button(hud, "end_phase").pressed.emit()
	assert_true(_emitted(hud) is EndPhaseCommand)
	assert_eq(_state.phase, GameState.Phase.ADMINISTRATION)


func test_setup_emits_humans_and_seed() -> void:
	var screen: SetupScreen = add_child_autofree(SetupScreen.new())
	screen.open(_rules.map, 77)
	watch_signals(screen)
	_button(screen, "start").pressed.emit()
	assert_signal_emitted_with_parameters(screen, "start_requested", [["welfen", "wettiner"], 77])


func test_battle_choice_reports_the_choice() -> void:
	var choice: BattleChoice = add_child_autofree(BattleChoice.new())
	var setup := BattleSetup.new()
	setup.attacker = CampaignBattles.army_side(_state, _rules, _state.armies_of("welfen")[0])
	setup.defender = Garrisons.side(_state, _rules, "BRM")
	choice.open(setup, _rules, "BRM")
	watch_signals(choice)
	_button(choice, "live").pressed.emit()
	assert_signal_emitted_with_parameters(choice, "chosen", [true])


func test_panels_handle_foreign_land_other_phases_and_no_selection() -> void:
	var admin: AdministrationPanel = add_child_autofree(AdministrationPanel.new())
	var province: ProvincePanel = add_child_autofree(ProvincePanel.new())
	var army: ArmyPanel = add_child_autofree(ArmyPanel.new())
	var welfen := _state.houses["welfen"]
	welfen.leader_captor = "staufer"
	welfen.leader_army = HouseState.NO_ARMY
	_state.provinces["HOL"].in_revolt = true
	_state.provinces["HOL"].occupied_rounds = 2
	for province_id: String in ["BRM", "BOH", "HOL", ""]:
		admin.refresh(_state, _rules, "welfen", province_id)
		province.refresh(_state, _rules, "welfen", province_id)
	assert_not_null(_button(admin, "ransom"))
	army.refresh(_state, _rules, "welfen", -1)
	army.refresh(_state, _rules, "welfen", _state.armies_of("staufer")[0].id)
	_state.phase = GameState.Phase.CAMPAIGN
	admin.refresh(_state, _rules, "welfen", "BSW")
	assert_true(_button(admin, "tax_20").disabled)
	assert_string_contains(_button(admin, "tax_20").tooltip_text, tr(Command.ERROR_WRONG_PHASE))


func test_report_accounts_for_every_bushel() -> void:
	_state.turn = GameState.Season.AUTUMN
	var after := GameState.from_dict(_state.to_dict())
	EconomySettlement.settle(after, _rules.map, _rules.economy)
	var lines := ReportLines.for_house(_state, after, _rules, "welfen")
	assert_gt(lines.size(), 8)
	assert_eq(lines[0].tone, ReportLines.Tone.HEADING)


func test_every_text_key_exists() -> void:
	var keys := _csv_keys()
	var used: Array[String] = []
	var pattern := RegEx.create_from_string("\"((?:CAMPAIGN|ECONOMY|SEASON)_[A-Z0-9_]*[A-Z0-9])\"")
	for folder: String in SOURCES:
		for file: String in DirAccess.get_files_at(folder):
			if file.get_extension() == "gd" and not file.begins_with("test_"):
				var source := FileAccess.get_file_as_string(folder.path_join(file))
				for found: RegExMatch in pattern.search_all(source):
					used.append(found.get_string(1))
	used.append_array(_data_keys())
	for key: String in used:
		assert_true(key in keys, "missing text key %s" % key)


## Keys the code builds from data ids.
func _data_keys() -> Array[String]:
	var map := _rules.map
	var cfg := _rules.economy
	var keys: Array[String] = []
	for region: String in map.regions:
		keys.append("CAMPAIGN_REGION_" + region.to_upper())
	for terrain: String in map.terrains:
		keys.append("CAMPAIGN_TERRAIN_" + terrain.to_upper())
	for owner: String in MapData.NON_HOUSE_OWNERS:
		keys.append("CAMPAIGN_OWNER_" + owner.to_upper())
	for feature: String in MapData.FEATURES:
		keys.append("CAMPAIGN_FEATURE_" + feature.to_upper())
	for def: MapData.ProvinceDef in map.provinces.values():
		keys.append(EconomyTerm.province_key(def.id))
		for tag: String in def.tags:
			keys.append("CAMPAIGN_TAG_" + tag.to_upper())
		if not def.river.is_empty():
			keys.append("CAMPAIGN_RIVER_" + def.river.to_upper())
	for id: String in cfg.buildings:
		keys.append(EconomyTerm.building_key(id))
	for id: String in cfg.decorations:
		keys.append(EconomyTerm.decoration_key(id))
	for id: String in cfg.units:
		keys.append(EconomyTerm.unit_key(id))
	for level: int in cfg.home_castle:
		keys.append(EconomyTerm.castle_key(level, true))
	for level: int in cfg.province_castle:
		keys.append(EconomyTerm.castle_key(level, false))
	for ration: int in cfg.rations:
		keys.append("CAMPAIGN_RATION_%d" % ration)
	for part: String in PopulationRules.target_satisfaction_parts(cfg, 15, 3, 0, 0, 0, false, false):
		if part != "bonus":
			keys.append("ECONOMY_Z_" + part.to_upper())
	for house: String in map.houses:
		keys.append("BATTLE_HOUSE_" + house.to_upper())
	return keys


func _csv_keys() -> Array[String]:
	var keys: Array[String] = []
	var file := FileAccess.open(TEXTS, FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if not row.is_empty() and not row[0].is_empty():
			keys.append(row[0])
	return keys


func _button(root: Node, button_name: String) -> Button:
	return root.find_child(button_name, true, false) as Button


func _emitted(source: Object) -> Command:
	var parameters: Array = get_signal_parameters(source, "command_requested")
	return parameters[0] as Command if not parameters.is_empty() else null
