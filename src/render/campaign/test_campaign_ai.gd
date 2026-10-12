extends GutTest
## The campaign scene with computer opponents (M7): the setup's choices make the computer
## houses, and once they played the debug overlay lists what each of them weighed.

const SEED := 1198

var _scene: Node


func before_each() -> void:
	_scene = (load("res://src/render/campaign/campaign_main.tscn") as PackedScene).instantiate()
	add_child_autofree(_scene)


func test_the_setup_starts_a_game_with_the_chosen_computers() -> void:
	var setup: SetupScreen = _scene.get("_setup")
	assert_true(setup.visible, "the game opens on the setup")
	var computers: Dictionary[String, Array] = {
		"wettiner": ["diplomat", 3], "staufer": ["merchant", 0], "wittelsbacher": ["builder", 2]
	}
	setup.start_requested.emit(["welfen"] as Array[String], SEED, computers)
	var session := _session()
	assert_eq(session.humans, ["welfen"] as Array[String])
	assert_false(session.state.houses["welfen"].is_computer())
	for house: String in computers:
		var owner := session.state.houses[house]
		assert_eq(owner.personality, computers[house][0], house)
		assert_eq(owner.difficulty, computers[house][1], house)
	assert_true(session.is_human_turn(), "the computers moved until the human's turn")
	var handover: HandoverScreen = _scene.get("_handover")
	assert_false(handover.visible, "one human needs no handover")


func test_without_a_choice_the_data_opponents_play() -> void:
	_scene.call("start", ["welfen", "staufer"] as Array[String], SEED)
	var state := _session().state
	var config := AiConfig.load_file()
	for house: String in ["wettiner", "wittelsbacher"]:
		assert_eq(state.houses[house].personality, config.personality_of(house))
		assert_eq(state.houses[house].difficulty, config.default_difficulty)
	assert_false(state.houses["staufer"].is_computer())


func test_the_overlay_shows_what_the_computers_weighed() -> void:
	var setup: SetupScreen = _scene.get("_setup")
	(setup.find_child("start", true, false) as Button).pressed.emit()
	var session := _session()
	var ai: AiPlayer = _scene.get("ai")
	var guard := 0
	while ai.logs.size() < 3 and guard < 20:
		guard += 1
		_dismiss_screens()
		_scene.call("execute", EndPhaseCommand.new(session.rules, session.active_house()))
	assert_eq(ai.logs.size(), 3, "every computer house played")
	_dismiss_screens()
	var overlay: AiDebugOverlay = _scene.get("_ai_overlay")
	assert_false(overlay.visible, "hidden until asked for")
	overlay._input(_f3())
	assert_true(overlay.visible)
	var rows := 0
	for _i: int in overlay.computer_houses().size():
		assert_eq(overlay.row_count(), ai.logs[overlay.house].entries.size(), overlay.house)
		rows += overlay.row_count()
		overlay.cycle(1)
	assert_gt(rows, 0, "the computers weighed options")
	overlay._input(_f3())
	assert_false(overlay.visible)


func test_the_overlay_stays_away_while_the_castle_covers_the_table() -> void:
	_scene.call("start", ["welfen"] as Array[String], SEED)
	_dismiss_screens()
	_scene.call("_open_castle", _session().state.houses["welfen"].home_province)
	await wait_process_frames(1)
	var overlay: AiDebugOverlay = _scene.get("_ai_overlay")
	overlay._input(_f3())
	assert_false(overlay.visible)
	_scene.call("_close_castle")
	await wait_process_frames(1)
	overlay._input(_f3())
	assert_true(overlay.visible)


func _session() -> CampaignSession:
	return _scene.get("session")


func _f3() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_F3
	event.pressed = true
	return event


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
