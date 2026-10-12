extends GutTest
## The campaign scene end to end (M3 acceptance): two houses play eight rounds on the war table
## and every settlement's gold change equals the formulas' breakdown; a battle on the way is
## fought live in the battle scene and its result changes the map.

const HUMANS: Array[String] = ["welfen", "staufer"]
const SEED := 1198
const ROUNDS := 8

var _scene: Node


func before_each() -> void:
	_scene = (load("res://src/render/campaign/campaign_main.tscn") as PackedScene).instantiate()
	add_child_autofree(_scene)
	_scene.call("start", HUMANS, SEED)


func test_two_houses_play_eight_rounds_and_the_numbers_follow_the_formulas() -> void:
	var session: CampaignSession = _scene.get("session")
	var rules := session.rules
	var settlements := 0
	var guard := 0
	while session.state.turn < ROUNDS and guard < 200:
		guard += 1
		_dismiss_screens()
		var state := session.state
		var house := state.active_house()
		if state.phase == GameState.Phase.ADMINISTRATION:
			_administrate(rules, house, state.turn)
		var before_turn := state.turn
		_execute(EndPhaseCommand.new(rules, house))
		if session.state.turn != before_turn:
			settlements += 1
			_check_settlement(session)
	assert_eq(session.state.turn, ROUNDS, "eight rounds were played")
	assert_eq(settlements, ROUNDS)


func test_a_battle_on_the_way_is_fought_live_and_changes_the_map() -> void:
	var session: CampaignSession = _scene.get("session")
	_dismiss_screens()
	while not (session.active_house() == "welfen" and session.state.phase == GameState.Phase.CAMPAIGN):
		_execute(EndPhaseCommand.new(session.rules, session.active_house()))
		_dismiss_screens()
	var welfen := session.state.armies_of("welfen")[0]
	var raiders := session.state.add_army("staufer", "HOL")
	raiders.add_company("levy")
	_scene.call("_on_army_clicked", welfen.id)
	_scene.call("_on_province_clicked", "HOL")
	var choice: BattleChoice = _scene.get("_choice")
	assert_true(choice.visible, "the player is asked how to fight")
	choice.chosen.emit(true)
	var battle: Node = _scene.get("_battle")
	assert_not_null(battle, "the battle scene runs")
	var table: MapTable = _scene.get("_table")
	assert_false(table.visible, "the war table waits behind the battle")
	var sim: BattleSim = battle.get("_sim")
	var limit := sim.rules.deploy_ticks() + sim.rules.time_limit_ticks() + 1
	while not sim.is_over() and sim.state.tick < limit:
		battle.call("_tick")
	var won := sim.result().attacker_won
	var panel: BattleResultPanel = battle.get("_result_panel")
	panel.continue_requested.emit()
	assert_true(table.visible, "back on the war table")
	var army := session.state.army(welfen.id)
	if won:
		assert_eq(army.province, "HOL", "the winner holds Holstein")
		assert_null(session.state.army(raiders.id))
	else:
		assert_true(army == null or army.province != "HOL", "the loser fell back")


func _administrate(rules: GameRules, house: String, turn: int) -> void:
	var cfg := rules.economy
	var home: String = _session().state.houses[house].home_province
	match turn:
		0:
			_execute(SetTaxRateCommand.new(cfg, house, 20))
			_execute(BuildCommand.new(cfg, rules.map, house, home, "granary"))
		1:
			_execute(RecruitCommand.new(cfg, rules.map, house, home, "spearmen"))
			_execute(TradeGrainCommand.new(cfg, house, 50))
		2:
			_execute(SetRationCommand.new(cfg, house, 4))
		4:
			_execute(TradeGrainCommand.new(cfg, house, -40))


func _check_settlement(session: CampaignSession) -> void:
	var before := session.before_settlement
	assert_not_null(before)
	var report: SettlementReport = _scene.get("_report")
	assert_true(report.visible, "the settlement report opens")
	for house: String in HUMANS:
		var terms := EconomyBreakdown.gold_change(before, session.rules.map, session.rules.economy, house)
		var expected := EconomyTerm.sum(terms)
		var actual := session.state.houses[house].gold - before.houses[house].gold
		assert_almost_eq(actual, expected, 1e-6, "%s gold in round %d" % [house, before.turn])


func _execute(command: Command) -> void:
	_scene.call("execute", command)


## Closes report and handover as a player would; the event dialog is only hidden, since the
## test ends event phases with EndPhaseCommand (default choices).
func _dismiss_screens() -> void:
	for name: String in ["_report", "_handover", "_events"]:
		var screen: Control = _scene.get(name)
		while screen.visible:
			screen.visible = false
			if screen is SettlementReport:
				(screen as SettlementReport).closed.emit()
			elif screen is HandoverScreen:
				(screen as HandoverScreen).confirmed.emit()


func _session() -> CampaignSession:
	return _scene.get("session")


func test_a_coronation_through_the_scene_ends_on_the_illuminated_page() -> void:
	_dismiss_screens()
	var session := _session()
	var state := session.state
	var house := session.active_house()
	state.turn = GameState.Season.WINTER
	for id: String in ["SPT", "AAC"]:
		state.provinces[id].owner = house
	for id: String in ["KOE", "TRI", "PFA", "BRB"]:
		state.crown.set_favour(id, house, 60.0, 100.0)
	_execute(CoronationCommand.new(session.rules.map, house))
	assert_eq(state.winner, house)
	var victory: VictoryScreen = _scene.get("_victory")
	assert_true(victory.visible, "the victory screen opens")
	var plate := victory.find_child("coronation_plate", true, false) as CoronationPlate
	assert_true(plate.visible, "with the coronation plate")


func test_the_province_panel_opens_the_castle_and_closing_returns_to_the_table() -> void:
	_dismiss_screens()
	var panel: ProvincePanel = _scene.get("_province_panel")
	var castle: CastleView = _scene.get("_castle")
	var table: MapTable = _scene.get("_table")
	panel.castle_requested.emit(_session().state.houses["welfen"].home_province)
	assert_true(castle.visible, "the castle view opens")
	assert_eq(table.process_mode, Node.PROCESS_MODE_DISABLED, "the war table rests meanwhile")
	castle.closed.emit()
	assert_false(castle.visible)
	assert_eq(table.process_mode, Node.PROCESS_MODE_INHERIT, "back on the war table")


func test_an_event_card_is_answered_in_the_dialog() -> void:
	_dismiss_screens()
	var session := _session()
	var house := session.active_house()
	var card := EventState.EventCard.create("jugglers", house, "")
	session.state.phase = GameState.Phase.EVENT
	session.state.events.drawn.assign([card])
	session.state.events.pending = 1
	_scene.call("_after_change")
	var dialog: EventCardDialog = _scene.get("_events")
	assert_true(dialog.visible, "the card waits for an answer")
	var gold := session.state.houses[house].gold
	(dialog.find_child("choice_accept", true, false) as Button).pressed.emit()
	assert_eq(session.state.houses[house].gold, gold - 20.0)
	assert_eq(session.state.phase, GameState.Phase.ADMINISTRATION)
	assert_true(dialog.visible, "the dialog sums up the turn")
	(dialog.find_child("continue", true, false) as Button).pressed.emit()
	assert_false(dialog.visible)
	_scene.call("_after_change")
	assert_false(dialog.visible, "once a turn")
