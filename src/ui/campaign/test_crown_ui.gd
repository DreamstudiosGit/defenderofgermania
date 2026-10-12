extends GutTest
## The realm tab shows every elector's favour and vote, emits gift, embassy, homage, penance and
## coronation commands without changing the state, and offers the coronation exactly when the
## command accepts it; the HUD shows the votes and the ban; a coronation ends on the
## illuminated page.

const WINTER_TURN := 3
const HOUSE := "welfen"

var _rules: GameRules
var _map: MapData
var _state: GameState


func before_all() -> void:
	_rules = GameRules.load_files()
	_map = _rules.map


func before_each() -> void:
	_state = GameSetup.create(_map, _rules.economy, 1)
	_state.active_index = _state.turn_order.find(HOUSE)


func test_the_tab_lists_seven_electors_with_favour_and_vote() -> void:
	_state.crown.set_favour("KOE", HOUSE, 62.0, 100.0)
	_state.crown.set_favour("TRI", "staufer", 61.0, 100.0)
	var panel := _panel()
	var votes := CrownRules.votes(_state, _map)
	assert_eq(_map.electors().size(), 7)
	for id: String in _map.electors():
		var row := panel.find_child("lord_" + id, true, false)
		assert_not_null(row, "a row for elector %s" % id)
		var bar := row.find_child("bar", true, false) as FavourBar
		assert_eq(bar.value, _state.crown.favour_of(id, HOUSE), "favour of %s" % id)
		var vote := row.find_child("vote", true, false) as Label
		assert_eq(vote.text, CrownFormat.vote(_state, _map, id, HOUSE, votes[id]))
	var you := tr("CAMPAIGN_CROWN_YOU")
	assert_eq(_text(panel, "lord_KOE", "vote"), tr("CAMPAIGN_CROWN_VOTE_FOR") % you)
	var staufer := CampaignFormat.house_name("staufer")
	assert_eq(_text(panel, "lord_TRI", "vote"), tr("CAMPAIGN_CROWN_VOTE_FOR") % staufer)
	assert_eq(_text(panel, "lord_PFA", "vote"), tr("CAMPAIGN_CROWN_VOTE_ABSTAINS"))
	assert_eq(_text(panel, "lord_KOE", "favour"), tr("CAMPAIGN_CROWN_FAVOUR") % "62")
	var marks := (_part(panel, "lord_KOE", "bar") as FavourBar).marks
	assert_eq(marks, PackedFloat32Array([60.0, 50.0]), "vote and archbishop marks")
	assert_true((_part(panel, "lord_KOE", "church") as Label).visible, "Cologne is church")
	assert_false((_part(panel, "lord_PFA", "church") as Label).visible)


func test_a_gift_emits_a_gift_command_for_that_lord() -> void:
	var panel := _panel()
	var gold := _state.houses[HOUSE].gold
	watch_signals(panel)
	_button(panel, "gift_TRI").pressed.emit()
	var command := _emitted(panel) as GiftCommand
	assert_not_null(command)
	assert_eq(command.province, "TRI")
	assert_eq(command.house, HOUSE)
	assert_eq(_state.houses[HOUSE].gold, gold, "the tab must not change the state")
	assert_eq(_state.crown.favour_of("TRI", HOUSE), 30.0)


func test_embassy_and_homage_emit_their_commands() -> void:
	_state.crown.set_favour("BBT", HOUSE, 80.0, 100.0)
	var panel := _panel()
	assert_null(_button(panel, "homage_ELS"), "homage is offered only from favour 80")
	watch_signals(panel)
	_button(panel, "embassy_BOH").pressed.emit()
	var embassy := _emitted(panel) as PlayPatronCommand
	assert_eq(embassy.card, PlayPatronCommand.EMBASSY)
	assert_eq(embassy.elector, "BOH")
	_button(panel, "homage_BBT").pressed.emit()
	var homage := _emitted(panel) as HomageCommand
	assert_eq(homage.province, "BBT")
	assert_eq(homage.execute(_state), "")
	panel.refresh(_state, _rules, HOUSE, "BSW")
	assert_null(panel.find_child("lord_BBT", true, false), "Brabant is no neutral lord any more")


func test_the_coronation_button_is_enabled_exactly_when_the_command_validates() -> void:
	var panel := _panel()
	_assert_coronation_matches(panel, "spring")
	_state.turn = WINTER_TURN
	_assert_coronation_matches(panel, "winter without pillars")
	for id: String in ["SPT", "AAC"]:
		_state.provinces[id].owner = HOUSE
	for id: String in ["KOE", "TRI", "PFA"]:
		_state.crown.set_favour(id, HOUSE, 60.0, 100.0)
	_assert_coronation_matches(panel, "three votes")
	assert_true(_button(panel, "coronation").disabled)
	_state.crown.set_favour("BRB", HOUSE, 60.0, 100.0)
	_assert_coronation_matches(panel, "row 1: true regalia, Aachen, four votes")
	var crown := _button(panel, "coronation")
	assert_false(crown.disabled)
	assert_eq(crown.text, tr("CAMPAIGN_CROWN_CORONATION_AT") % CampaignFormat.province_name("AAC"))
	watch_signals(panel)
	crown.pressed.emit()
	assert_true(_emitted(panel) is CoronationCommand)
	assert_false(_state.is_over(), "the tab must not change the state")


func test_penance_shows_only_while_banned_and_church_electors_refuse() -> void:
	_state.crown.set_favour("KOE", HOUSE, 62.0, 100.0)
	var panel := _panel()
	assert_null(_button(panel, "penance"))
	_state.houses[HOUSE].is_banned = true
	panel.refresh(_state, _rules, HOUSE, "BSW")
	assert_eq(_text(panel, "lord_KOE", "vote"), tr("CAMPAIGN_CROWN_VOTE_BANNED"))
	var penance := _button(panel, "penance")
	assert_false(penance.disabled)
	watch_signals(panel)
	penance.pressed.emit()
	assert_true(_emitted(panel) is PenanceCommand)


func test_the_hud_shows_the_votes_and_the_ban() -> void:
	_state.crown.set_favour("KOE", HOUSE, 62.0, 100.0)
	var hud: CampaignHud = add_child_autofree(CampaignHud.new())
	hud.refresh(_state, _rules, HOUSE)
	var votes := _button(hud, "crown")
	assert_eq(votes.text, tr("CAMPAIGN_CROWN_HUD_VOTES") % [1, 7])
	assert_string_contains(votes.tooltip_text, CrownFormat.votes(_state, _map, HOUSE))
	_state.houses[HOUSE].is_banned = true
	hud.refresh(_state, _rules, HOUSE)
	var banned := "%s · %s" % [tr("CAMPAIGN_CROWN_HUD_VOTES") % [0, 7], tr("CAMPAIGN_CROWN_HUD_BAN")]
	assert_eq(votes.text, banned, "Cologne refuses the banned")


func test_the_victory_screen_shows_the_coronation_plate_only_after_a_coronation() -> void:
	var screen: VictoryScreen = add_child_autofree(VictoryScreen.new())
	var plate := screen.find_child("coronation_plate", true, false) as CoronationPlate
	var timed := GameState.from_dict(_state.to_dict())
	timed.turn = _map.campaign.max_rounds
	Victory.check(timed, _rules)
	screen.open(timed, _rules)
	assert_false(plate.visible, "a time-limit ending keeps the old screen")
	_state.turn = WINTER_TURN
	for id: String in ["SPT", "AAC"]:
		_state.provinces[id].owner = HOUSE
	for id: String in ["KOE", "TRI", "PFA", "BRB"]:
		_state.crown.set_favour(id, HOUSE, 60.0, 100.0)
	assert_eq(CoronationCommand.new(_map, HOUSE).execute(_state), "")
	screen.open(_state, _rules)
	assert_true(plate.visible)
	var heading := plate.find_child("heading", true, false) as Label
	var site := CampaignFormat.province_name("AAC")
	assert_eq(heading.text, tr("CAMPAIGN_CROWN_PLATE_CORONATION_SITE") % site)
	var chronicle := plate.find_child("chronicle", true, false) as Label
	var line := tr("CAMPAIGN_CROWN_PLATE_WELFEN_CORONATION_SITE")
	assert_eq(chronicle.text, line.substr(1), "the first letter is the gilded initial")


func _assert_coronation_matches(panel: AdministrationPanel, moment: String) -> void:
	panel.refresh(_state, _rules, HOUSE, "BSW")
	var error := CoronationCommand.new(_map, HOUSE).validate(_state)
	var crown := _button(panel, "coronation")
	assert_eq(crown.disabled, not error.is_empty(), moment)
	if not error.is_empty():
		assert_string_contains(crown.tooltip_text, tr(error), moment)
		var reason := panel.find_child("coronation_reason", true, false) as Label
		assert_eq(reason.text, tr(error), moment)


func _panel() -> AdministrationPanel:
	var panel: AdministrationPanel = add_child_autofree(AdministrationPanel.new())
	panel.refresh(_state, _rules, HOUSE, "BSW")
	return panel


func _text(root: Node, row: String, label: String) -> String:
	return (_part(root, row, label) as Label).text


func _part(root: Node, row: String, part: String) -> Node:
	return root.find_child(row, true, false).find_child(part, true, false)


func _button(root: Node, button_name: String) -> Button:
	return root.find_child(button_name, true, false) as Button


func _emitted(source: Object) -> Command:
	var parameters: Array = get_signal_parameters(source, "command_requested")
	return parameters[0] as Command if not parameters.is_empty() else null
