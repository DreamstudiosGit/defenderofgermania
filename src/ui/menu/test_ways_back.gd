extends GutTest
## Every mode has a way back to the main menu: the campaign's setup and victory screens and
## the quick battle's start menu ask for it through a signal, and no scene quits the process
## any more — only the menu's "quit" does, through App.

const SCENES: Array[String] = [
	"res://src/render/battle/battle_main.gd", "res://src/render/campaign/campaign_main.gd",
	"res://src/render/joust/joust_main.gd", "res://src/render/siege/trebuchet_main.gd",
	"res://src/render/raid/raid_main.gd", "res://src/render/merchant/merchant_main.gd",
	"res://src/render/menu/main_menu.gd",
]
const QUIT_CALL := "get_tree().quit("

var _locale := ""


func before_each() -> void:
	_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_locale)


func test_the_setup_screen_goes_back_by_button_and_by_cancel() -> void:
	var setup: SetupScreen = add_child_autofree(SetupScreen.new())
	watch_signals(setup)
	_press("ui_cancel")
	assert_signal_not_emitted(setup, "back_requested", "a hidden setup leaves the key alone")
	setup.open(GameRules.load_files(), AiConfig.load_file(), 77)
	assert_not_null(get_viewport().gui_get_focus_owner(), "the open setup holds the focus")
	(setup.find_child("back", true, false) as Button).pressed.emit()
	assert_signal_emit_count(setup, "back_requested", 1)
	_press("ui_cancel")
	assert_signal_emit_count(setup, "back_requested", 2)
	var seed_field: LineEdit = setup.get("_seed")
	seed_field.edit()
	assert_true(seed_field.is_editing())
	_press("ui_cancel")
	assert_false(seed_field.is_editing(), "cancel while typing the seed ends the typing")
	assert_signal_emit_count(setup, "back_requested", 2, "and stays in the setup")
	_press("ui_cancel")
	assert_signal_emit_count(setup, "back_requested", 3)
	assert_signal_not_emitted(setup, "start_requested")


func test_the_victory_screen_offers_the_main_menu_next_to_a_new_game() -> void:
	var victory: VictoryScreen = add_child_autofree(VictoryScreen.new())
	var rules := GameRules.load_files()
	var state := GameSetup.create(rules.map, rules.economy, 1)
	state.winner = "welfen"
	victory.open(state, rules)
	var again := victory.find_child("new_game", true, false) as Button
	var menu := victory.find_child("main_menu", true, false) as Button
	assert_eq(get_viewport().gui_get_focus_owner(), again)
	assert_eq(menu.get_parent(), again.get_parent(), "side by side")
	watch_signals(victory)
	menu.pressed.emit()
	assert_signal_emitted(victory, "main_menu_requested")
	assert_signal_not_emitted(victory, "new_game_requested")


func test_the_quick_battle_menu_goes_back_and_is_no_prototype() -> void:
	var menu: BattleMenu = add_child_autofree(BattleMenu.new())
	watch_signals(menu)
	(menu.find_child("back", true, false) as Button).pressed.emit()
	assert_signal_emitted(menu, "back_requested")
	assert_signal_not_emitted(menu, "start_requested")
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		assert_eq(tr("BATTLE_MENU_TITLE"), tr("MENU_QUICK_BATTLE"), locale)
		assert_false("rototyp" in tr("BATTLE_MENU_TITLE"), locale)


func test_no_scene_quits_the_process() -> void:
	for path: String in SCENES:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.is_empty(), path)
		assert_false(QUIT_CALL in source, "%s leaves through App" % path)


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
