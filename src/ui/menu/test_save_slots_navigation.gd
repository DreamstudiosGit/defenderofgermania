extends GutTest
## The list of saved campaigns under keys and a controller alone: cancel closes the question,
## then the list, and never reaches the menu behind; every row and button can be reached and
## the focus never leaves the list; it works while the tree is paused and fits the base
## window at the largest UI scale. Saves live in a folder of the test's own.

const FOLDER := "user://test_save_slots_navigation"
const ALL_HOUSES: Array[String] = ["welfen", "wettiner", "staufer", "wittelsbacher"]

var _folder := ""
var _locale := ""
var _rules: GameRules
var _screen: SaveSlotsScreen


## Stands in for the menu behind the list: it counts the cancels that reach it.
class Caller:
	extends Control
	var cancels := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			cancels += 1


func before_all() -> void:
	_rules = GameRules.load_files()


func before_each() -> void:
	_folder = SaveGames.folder
	_locale = TranslationServer.get_locale()
	SaveGames.folder = FOLDER
	_remove_saves()
	_screen = add_child_autofree(SaveSlotsScreen.new())


func after_each() -> void:
	get_tree().paused = false
	_remove_saves()
	DirAccess.remove_absolute(FOLDER)
	SaveGames.folder = _folder
	TranslationServer.set_locale(_locale)


func test_cancel_closes_the_question_then_the_list_and_never_reaches_the_caller() -> void:
	var caller: Caller = add_child_autofree(Caller.new())
	var screen := SaveSlotsScreen.new()
	caller.add_child(screen)
	SaveGames.write(_state(1), "slot_1")
	var before: Button = add_child_autofree(Button.new())
	before.grab_focus()
	screen.open(SaveSlotsScreen.Mode.SAVE, _state(2))
	watch_signals(screen)
	(screen.find_child("slot_1", true, false) as SaveSlotRow).button.pressed.emit()
	var dialog := screen.find_child("ask_dialog", true, false) as ConfirmDialog
	assert_true(dialog.visible)
	_press("ui_cancel")
	assert_false(dialog.visible)
	assert_true(screen.visible, "only the question is gone")
	_press("ui_cancel")
	assert_false(screen.visible)
	assert_signal_emit_count(screen, "closed", 1)
	assert_eq(caller.cancels, 0, "the menu behind never saw them")
	assert_eq(_focus(), before, "the focus is back where it was")
	_press("ui_cancel")
	assert_eq(caller.cancels, 1, "a closed list lets them pass")
	screen.close()
	assert_signal_emit_count(screen, "closed", 1, "closing a closed list reports nothing")


func test_closing_with_a_question_open_drops_the_question() -> void:
	SaveGames.write(_state(1), "slot_1")
	var state := _state(2)
	_screen.open(SaveSlotsScreen.Mode.SAVE, state)
	_row("slot_1").button.pressed.emit()
	_screen.close()
	assert_false(_dialog().visible)
	_screen.open(SaveSlotsScreen.Mode.SAVE, state)
	assert_false(_dialog().visible, "a new start asks nothing")
	_dialog().confirmed.emit()
	assert_eq(SaveGames.header("slot_1")["turn"], 1, "and an old answer writes nothing")


func test_it_works_while_the_tree_is_paused() -> void:
	SaveGames.write(_state(1), "slot_1")
	get_tree().paused = true
	_screen.open(SaveSlotsScreen.Mode.LOAD)
	watch_signals(_screen)
	_press("ui_accept")
	assert_signal_emitted_with_parameters(_screen, "load_requested", ["slot_1"])
	_screen.open(SaveSlotsScreen.Mode.SAVE, _state(2))
	_press("ui_down")
	_press("ui_accept")
	assert_eq(SaveGames.status("slot_2"), SaveGames.Status.INTACT, "saving works too")
	_press("ui_cancel")
	assert_false(_screen.visible)


func test_keys_alone_reach_everything_and_never_leave_the_list() -> void:
	_cover_the_viewport_with_buttons()
	SaveGames.write(_state(1), SaveGames.AUTOSAVE)
	_write_header("slot_1", {"version": GameState.SAVE_VERSION, "saved_unix": 9.0e12})
	_write_header("slot_3", {"version": GameState.SAVE_VERSION + 1})
	_screen.open(SaveSlotsScreen.Mode.LOAD)
	await wait_process_frames(2)
	var autosave := _row(SaveGames.AUTOSAVE).button
	var first := _row("slot_1")
	var third := _row("slot_3")
	var back := _screen.find_child("back", true, false) as Button
	assert_eq(_focus(), first.button, "the newest save")
	_walk(["ui_up"], autosave)
	_walk(["ui_up", "ui_left", "ui_right"], autosave, "the first row has no way further")
	_walk(["ui_down"], first.button)
	_walk(["ui_left"], first.button)
	_walk(["ui_right"], first.delete)
	_walk(["ui_right", "ui_up"], first.delete)
	_walk(["ui_left"], first.button)
	_walk(["ui_right", "ui_down"], third.delete, "past the empty slot")
	_walk(["ui_left", "ui_right"], third.delete, "its row cannot be picked")
	_walk(["ui_up"], first.delete)
	_walk(["ui_down", "ui_down"], back)
	_walk(["ui_down", "ui_left", "ui_right"], back)
	_walk(["ui_up"], first.button, "up leads to the last row, not to a delete button")
	_walk(["ui_down", "ui_focus_next"], autosave, "Tab goes round")
	_walk(["ui_focus_prev"], back)
	_walk(["ui_focus_prev"], third.delete)


func test_the_ways_follow_what_the_slots_hold_after_a_change() -> void:
	_cover_the_viewport_with_buttons()
	var state := _state(3)
	_screen.open(SaveSlotsScreen.Mode.SAVE, state)
	await wait_process_frames(2)
	var first := _row("slot_1")
	_walk(["ui_right"], first.button, "an empty slot has nothing to delete")
	_walk(["ui_accept", "ui_right"], first.delete, "a saved one has")
	_walk(["ui_up", "ui_down"], _screen.find_child("back", true, false) as Button)
	_walk(["ui_up"], _row("slot_3").button)
	_walk(["ui_up", "ui_up", "ui_up"], first.button, "the autosave is passed over")
	_walk(["ui_focus_prev"], _screen.find_child("back", true, false) as Button)


func test_it_fits_the_base_window_at_the_largest_ui_scale() -> void:
	for slot: String in SaveGames.SLOTS:
		SaveGames.write(_state(47, ALL_HOUSES), slot)
	SaveGames.write(_state(47, ALL_HOUSES), SaveGames.AUTOSAVE)
	SaveGames.write(_state(47, ALL_HOUSES), SaveGames.AUTOSAVE)
	_truncate(SaveGames.path(SaveGames.AUTOSAVE))
	var largest: float = UserSettings.SPEC[UserSettings.UI_SCALE][2]
	var frame: Control = add_child_autofree(Control.new())
	frame.size = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	) / largest
	var screen := SaveSlotsScreen.new()
	frame.add_child(screen)
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		screen.open(SaveSlotsScreen.Mode.SAVE, _state(1))
		await wait_process_frames(2)
		var panel := screen.find_child("panel", true, false) as Control
		assert_true(frame.get_global_rect().encloses(panel.get_global_rect()), locale)
		for slot: String in [SaveGames.AUTOSAVE] + SaveGames.SLOTS:
			var row := screen.find_child(slot, true, false) as SaveSlotRow
			var inside := row.button.get_global_rect()
			# What the row tells ends before its delete button begins.
			inside.end.x = row.delete.get_global_rect().position.x
			for part: String in ["saved", "houses"]:
				var rect := (row.button.find_child(part, true, false) as Control).get_global_rect()
				assert_true(inside.encloses(rect), "%s of %s (%s)" % [part, slot, locale])
		screen.close()


## A campaign in the given round with these human houses.
func _state(turn: int, humans: Array[String] = ["welfen"]) -> GameState:
	var computers: Dictionary[String, Array] = {}
	for house: String in ALL_HOUSES:
		if house not in humans:
			computers[house] = ["builder", 1]
	var state := CampaignSession.create(_rules, humans, 9, computers).state
	state.turn = turn
	return state


## A save file with this header and a real state.
func _write_header(slot: String, header: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	SaveFile.store(SaveGames.path(slot), SaveFile.encode(header, _state(0).to_bytes()))


func _truncate(file_path: String) -> void:
	var data := FileAccess.get_file_as_bytes(file_path)
	SaveFile.store(file_path, data.slice(0, data.size() >> 1))


## Presses the actions one after the other and expects the focus on `target` in the end.
func _walk(actions: Array[String], target: Control, why: String = "") -> void:
	for action: String in actions:
		_press(action)
	assert_eq(_focus(), target, "%s %s" % [", ".join(actions), why])


## Stands in for the scene behind the list: wherever Godot looks for a neighbour, one is.
func _cover_the_viewport_with_buttons() -> void:
	var grid: GridContainer = add_child_autofree(GridContainer.new())
	grid.columns = 9
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in 81:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	# The list was added first; in front of the buttons is where a modal belongs.
	_screen.move_to_front()


func _row(slot: String) -> SaveSlotRow:
	return _screen.find_child(slot, true, false) as SaveSlotRow


func _dialog() -> ConfirmDialog:
	return _screen.find_child("ask_dialog", true, false) as ConfirmDialog


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
