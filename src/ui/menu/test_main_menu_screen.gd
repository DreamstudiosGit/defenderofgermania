extends GutTest
## The main menu's screen: its entries ask through signals, Continue follows the saves,
## practice, credits, saved games and options open on top and give the focus back, keys alone
## reach everything, and every text key of the menu exists in both languages.

const FOLDER := "user://test_menu_screen_saves"
const TEXTS := "res://data/i18n/texts.csv"
const SOURCES: Array[String] = [
	"res://src/ui/menu/", "res://src/render/menu/", "res://src/ui/battle/battle_menu.gd",
	"res://src/ui/campaign/setup_screen.gd", "res://src/ui/campaign/victory_screen.gd",
]
const ENTRIES: Array[String] = [
	"continue", "new_campaign", "load", "quick_battle", "practice", "options", "credits", "quit",
]

var _folder := ""
var _locale := ""
var _screen: MainMenuScreen


func before_each() -> void:
	_folder = SaveGames.folder
	_locale = TranslationServer.get_locale()
	SaveGames.folder = FOLDER
	_remove_saves()
	_screen = add_child_autofree(MainMenuScreen.new())


func after_each() -> void:
	_remove_saves()
	DirAccess.remove_absolute(FOLDER)
	SaveGames.folder = _folder
	TranslationServer.set_locale(_locale)


func test_entries_stand_in_order_and_the_first_in_reach_has_the_focus() -> void:
	var names: Array[String] = []
	for entry: Button in _screen.entries.entries():
		names.append(str(entry.name))
	assert_eq(names, ENTRIES)
	assert_true(_entry("continue").disabled, "nothing to continue without a save")
	assert_eq(_focus(), _entry("new_campaign"))


func test_continue_follows_the_newest_save() -> void:
	TranslationServer.set_locale("de")
	var state := _campaign_state()
	state.turn = 11
	SaveGames.write(state, "slot_2")
	_screen.refresh_saves()
	_screen.entries.focus_first()
	var entry := _entry("continue")
	assert_false(entry.disabled)
	assert_eq(_focus(), entry)
	var saved_at := str(SaveGames.header("slot_2")["saved_at"])
	var info := entry.find_child("save_info", true, false) as Label
	assert_eq(info.text, "Runde 12 · %s" % SaveCaption.date(saved_at))
	watch_signals(_screen)
	_press("ui_accept")
	assert_signal_emitted_with_parameters(_screen, "continue_requested", ["slot_2"])
	SaveGames.remove("slot_2")
	_screen.refresh_saves()
	assert_true(entry.disabled, "the save is gone")
	assert_eq(info.text, tr("MENU_CONTINUE_NONE"))


func test_the_caption_writes_round_and_date_in_the_language() -> void:
	var header := {"turn": 4, "saved_at": "2026-11-09 07:05:59"}
	TranslationServer.set_locale("de")
	assert_eq(SaveCaption.of(header), "Runde 5 · 09.11.2026, 07:05")
	TranslationServer.set_locale("en")
	assert_eq(SaveCaption.of(header), "Round 5 · 2026-11-09, 07:05")
	assert_eq(SaveCaption.of({"turn": 0, "saved_at": "soon"}), "Round 1", "no date, no guess")
	assert_eq(SaveCaption.of({}), "")


func test_entries_ask_through_signals() -> void:
	watch_signals(_screen)
	for entry: String in ["new_campaign", "quick_battle", "quit"]:
		_entry(entry).pressed.emit()
		assert_signal_emitted(_screen, entry + "_requested")
	_screen.slots.load_requested.emit("slot_3")
	assert_signal_emitted_with_parameters(_screen, "load_requested", ["slot_3"])
	_screen.options.language_changed.emit()
	assert_signal_emitted(_screen, "language_changed")


func test_keys_alone_walk_the_entries_and_wrap_around() -> void:
	# Focus moves by where the entries stand, so the column needs its layout first.
	await wait_process_frames(2)
	_press("ui_down")
	assert_eq(_focus(), _entry("load"))
	_press("ui_up")
	_press("ui_up")
	assert_eq(_focus(), _entry("quit"), "up from the first entry in reach leads to the last")
	_press("ui_down")
	assert_eq(_focus(), _entry("new_campaign"), "and down from the last to the first")
	_press("ui_cancel")
	assert_eq(_focus(), _entry("new_campaign"), "cancel at the top changes nothing")


func test_a_first_save_puts_continue_back_into_the_round_of_entries() -> void:
	await wait_process_frames(2)
	SaveGames.write(_campaign_state(), "slot_1")
	_screen.refresh_saves()
	assert_eq(_focus(), _entry("new_campaign"), "the focus stays where it was")
	_press("ui_up")
	assert_eq(_focus(), _entry("continue"), "up no longer skips to the last entry")
	_press("ui_up")
	assert_eq(_focus(), _entry("quit"))
	_press("ui_down")
	assert_eq(_focus(), _entry("continue"))


func test_the_menu_fits_the_base_window_at_the_largest_ui_scale() -> void:
	var largest: float = UserSettings.SPEC[UserSettings.UI_SCALE][2]
	var frame: Control = add_child_autofree(Control.new())
	frame.size = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	) / largest
	var screen := MainMenuScreen.new()
	frame.add_child(screen)
	await wait_process_frames(2)
	var title := screen.find_child("name", true, false) as Control
	var last := screen.entries.find_child("quit", true, false) as Control
	assert_gt(
		title.get_global_rect().position.y, -MainMenuScreen.TITLE_HEADROOM,
		"the title's capitals stay on screen"
	)
	assert_lt(last.get_global_rect().end.y, frame.size.y, "and so does the last entry")


func test_practice_opens_in_place_and_cancel_returns_to_its_entry() -> void:
	_entry("practice").grab_focus()
	_press("ui_accept")
	assert_true(_screen.practice.visible)
	assert_false(_screen.entries.visible, "in place of the entries")
	assert_eq(_focus(), _screen.practice.find_child("joust", true, false))
	watch_signals(_screen)
	var modes: Array[StringName] = []
	for mode: Array in PracticeMenu.MODES:
		(_screen.practice.find_child(str(mode[0]), true, false) as Button).pressed.emit()
		modes.append(get_signal_parameters(_screen, "practice_requested")[0])
	assert_eq(modes, [&"joust", &"siege", &"raid", &"merchant"] as Array[StringName])
	_press("ui_cancel")
	assert_false(_screen.practice.visible)
	assert_true(_screen.entries.visible)
	assert_eq(_focus(), _entry("practice"), "the focus is back where it was")
	_press("ui_accept")
	(_screen.practice.find_child("back", true, false) as Button).pressed.emit()
	assert_false(_screen.practice.visible, "the back entry closes it too")
	assert_eq(_focus(), _entry("practice"))


func test_credits_open_on_top_and_close_with_cancel() -> void:
	_entry("credits").grab_focus()
	_press("ui_accept")
	assert_true(_screen.credits.visible)
	assert_eq(_focus(), _screen.credits.find_child("back", true, false))
	for entry: Button in _screen.entries.entries():
		assert_eq(entry.focus_mode, Control.FOCUS_NONE, "%s is out of reach behind it" % entry.name)
	_press("ui_cancel")
	assert_false(_screen.credits.visible)
	assert_eq(_focus(), _entry("credits"))
	assert_true(_entry("continue").disabled, "and Continue stays out of reach")
	assert_eq(_entry("continue").focus_mode, Control.FOCUS_NONE)


func test_saved_games_and_options_open_and_give_the_focus_back() -> void:
	_entry("load").pressed.emit()
	assert_true(_screen.slots.visible)
	_screen.slots.close()
	assert_eq(_focus(), _entry("load"))
	_entry("options").pressed.emit()
	assert_true(_screen.options.visible)
	_press("ui_cancel")
	assert_false(_screen.options.visible, "cancel closes the options")
	assert_eq(_focus(), _entry("options"))


func test_every_text_key_exists_in_both_languages() -> void:
	var texts: Dictionary[String, Array] = {}
	var file := FileAccess.open(TEXTS, FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			texts[row[0]] = [row[1], row[2]]
	var pattern := RegEx.create_from_string("\"((?:MENU|UI)_[A-Z0-9_]*[A-Z0-9])\"")
	var used: Dictionary[String, bool] = {}
	for source: String in _scripts():
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(source)):
			used[found.get_string(1)] = true
	assert_gt(used.size(), 20, "the menu's keys were found")
	for key: String in used:
		assert_true(texts.has(key), "missing text key %s" % key)
		if texts.has(key):
			assert_false(str(texts[key][0]).is_empty() or str(texts[key][1]).is_empty(), key)


func _scripts() -> Array[String]:
	var scripts: Array[String] = []
	for source: String in SOURCES:
		if source.get_extension() == "gd":
			scripts.append(source)
			continue
		for file: String in DirAccess.get_files_at(source):
			if file.get_extension() == "gd" and not file.begins_with("test_"):
				scripts.append(source.path_join(file))
	return scripts


func _campaign_state() -> GameState:
	var humans: Array[String] = ["welfen"]
	var computers: Dictionary[String, Array] = {}
	for house: String in ["wettiner", "staufer", "wittelsbacher"]:
		computers[house] = ["builder", 1]
	return CampaignSession.create(GameRules.load_files(), humans, 9, computers).state


func _entry(entry_name: String) -> Button:
	return _screen.entries.find_child(entry_name, true, false) as Button


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## Presses and releases an action the way a key or a controller button would.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)


func _remove_saves() -> void:
	for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
		SaveGames.remove(slot)
