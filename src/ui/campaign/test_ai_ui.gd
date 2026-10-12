extends GutTest
## The computer opponents on the campaign screens: the setup chooses who plays each house,
## personalities (random ones rolled from the seed) and difficulties; the handover names who
## plays the other houses; the debug overlay lists a computer house's options newest first and
## toggles with F3 and Back+Y.

var _rules: GameRules
var _config: AiConfig


func before_all() -> void:
	_rules = GameRules.load_files()
	_config = AiConfig.load_file()


func test_setup_emits_the_chosen_players_personalities_and_difficulties() -> void:
	var screen := _setup(5)
	_choose(screen, "player_staufer", SetupScreen.HUMAN)
	_choose(screen, "personality_wettiner", _config.default_house.keys().find("conqueror"))
	_choose(screen, "difficulty_wettiner", 3)
	_choose(screen, "difficulty_wittelsbacher", 0)
	watch_signals(screen)
	(screen.find_child("start", true, false) as Button).pressed.emit()
	var parameters: Array = get_signal_parameters(screen, "start_requested")
	assert_eq(parameters[0], ["welfen", "staufer"])
	assert_eq(parameters[1], 5)
	var computers: Dictionary = parameters[2]
	assert_eq(computers.keys(), ["wettiner", "wittelsbacher"])
	assert_eq(computers["wettiner"], ["conqueror", 3])
	assert_eq(computers["wittelsbacher"], [_config.personality_of("wittelsbacher"), 0])


func test_a_random_personality_is_rolled_from_the_seed() -> void:
	var random := _config.default_house.size()
	var rolls: Array[String] = []
	for seed_value: int in [1, 1, 2, 3, 4, 5, 6]:
		var screen := _setup(seed_value)
		for house: String in ["wettiner", "staufer", "wittelsbacher"]:
			_choose(screen, "personality_" + house, random)
		var computers := screen.computers(seed_value)
		for house: String in computers:
			assert_has(_config.default_house, computers[house][0], "a real personality")
		rolls.append(str(computers))
	assert_eq(rolls[0], rolls[1], "the same seed rolls the same opponents")
	var different := false
	for roll: String in rolls.slice(2):
		different = different or roll != rolls[0]
	assert_true(different, "other seeds roll others")


func test_setup_needs_a_human_and_asks_personality_only_of_computers() -> void:
	var screen := _setup(1)
	var start := screen.find_child("start", true, false) as Button
	var personality := screen.find_child("personality_welfen", true, false) as OptionButton
	assert_true(personality.disabled, "the human house has no personality")
	assert_eq(personality.focus_mode, Control.FOCUS_NONE, "and the focus skips it")
	_choose(screen, "player_welfen", SetupScreen.COMPUTER)
	assert_false(personality.disabled)
	assert_true(start.disabled, "nobody would play")
	_choose(screen, "player_staufer", SetupScreen.HUMAN)
	assert_false(start.disabled)
	assert_eq(screen.humans(), ["staufer"] as Array[String])


func test_handover_names_who_plays_the_other_houses() -> void:
	var state := GameSetup.create(_rules.map, _rules.economy, 1)
	state.houses["staufer"].personality = "conqueror"
	state.houses["staufer"].difficulty = 2
	var screen: HandoverScreen = add_child_autofree(HandoverScreen.new())
	screen.open(state, _rules, "welfen")
	assert_null(screen.find_child("house_welfen", true, false), "the house to move is the title")
	assert_string_contains(_label(screen, "house_staufer"), tr("CAMPAIGN_AI_DIFFICULTY_2"))
	assert_string_contains(_label(screen, "house_wettiner"), tr("CAMPAIGN_SETUP_HUMAN"))


func test_overlay_lists_the_last_turn_newest_first_and_toggles() -> void:
	var state := _with_computers(["staufer"])
	var ai := AiPlayer.new(_rules, _config)
	var history := AiLog.new()
	history.add(0, GameState.Phase.ADMINISTRATION, "build granary BSW", 1.234, false, "")
	history.add(0, GameState.Phase.ADMINISTRATION, "build granary BSW", 1.234, true, "")
	history.add(0, GameState.Phase.CAMPAIGN, "storm KOE", INF, false, "TURN_NOT_ENOUGH_GOLD")
	ai.logs["staufer"] = history
	var overlay: AiDebugOverlay = add_child_autofree(AiDebugOverlay.new())
	overlay.refresh(state, _rules, ai)
	assert_false(overlay.visible, "hidden until asked for")
	overlay._input(_key(KEY_F3))
	assert_true(overlay.visible)
	assert_eq(overlay.house, "staufer")
	assert_eq(overlay.row_count(), 3)
	var text := (overlay.find_child("options", true, false) as RichTextLabel).get_parsed_text()
	assert_lt(text.find("storm KOE"), text.find("build granary"), "newest first")
	assert_string_contains(text, "TURN_NOT_ENOUGH_GOLD")
	assert_string_contains(text, "✓")
	assert_string_contains(text, "∞")
	assert_string_contains(text, CampaignFormat.number(1.23, 2))
	overlay._input(_pad(JOY_BUTTON_BACK, true))
	overlay._input(_pad(JOY_BUTTON_Y, true))
	assert_false(overlay.visible, "Back+Y hides it")
	overlay._input(_pad(JOY_BUTTON_BACK, false))
	overlay._input(_pad(JOY_BUTTON_Y, true))
	assert_false(overlay.visible, "Y alone leaves it hidden")


func test_overlay_cycles_through_the_computer_houses() -> void:
	var state := _with_computers(["staufer", "wettiner"])
	var overlay: AiDebugOverlay = add_child_autofree(AiDebugOverlay.new())
	overlay.refresh(state, _rules, AiPlayer.new(_rules, _config))
	var houses := overlay.computer_houses()
	assert_eq(houses.size(), 2)
	overlay.toggle()
	assert_eq(overlay.row_count(), 0, "nothing weighed yet")
	var first := overlay.house
	overlay._input(_key(KEY_F4))
	assert_ne(overlay.house, first)
	overlay._input(_key(KEY_F4, true))
	assert_eq(overlay.house, first, "Shift+F4 goes back")
	(overlay.find_child("next", true, false) as Button).pressed.emit()
	assert_ne(overlay.house, first, "the arrow buttons cycle too")


## Keys built from data ids; the literal ones test_campaign_ui checks.
func test_every_personality_difficulty_and_category_has_a_text() -> void:
	var keys: Array[String] = ["CAMPAIGN_AI_PERSONALITY_" + AiFormat.RANDOM.to_upper()]
	for id: String in _config.default_house:
		keys.append("CAMPAIGN_AI_PERSONALITY_" + id.to_upper())
	for level: int in _config.difficulties.size():
		keys.append("CAMPAIGN_AI_DIFFICULTY_%d" % level)
	for category: String in AiConfig.CATEGORIES:
		keys.append("CAMPAIGN_AI_CATEGORY_" + category.to_upper())
	for key: String in keys:
		assert_ne(tr(key), key, "missing text key %s" % key)


func _setup(seed_value: int) -> SetupScreen:
	var screen: SetupScreen = add_child_autofree(SetupScreen.new())
	screen.open(_rules, _config, seed_value)
	return screen


func _choose(screen: SetupScreen, node_name: String, index: int) -> void:
	var choice := screen.find_child(node_name, true, false) as OptionButton
	choice.select(index)
	choice.item_selected.emit(index)


func _with_computers(houses: Array[String]) -> GameState:
	var state := GameSetup.create(_rules.map, _rules.economy, 1)
	for house: String in houses:
		state.houses[house].personality = _config.personality_of(house)
	return state


func _label(root: Node, node_name: String) -> String:
	var entry := root.find_child(node_name, true, false)
	assert_not_null(entry, node_name)
	if entry == null:
		return ""
	for child: Node in entry.get_children():
		if child is Label:
			return (child as Label).text
	return ""


func _key(code: Key, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.shift_pressed = shift
	event.pressed = true
	return event


func _pad(button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event
