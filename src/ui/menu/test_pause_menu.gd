extends GutTest
## The pause menu: it pauses the tree while open, offers what the scene allows (save and load
## with a state source, the scene's own entry), closes a sub-screen before it resumes and asks
## before it leaves. Its options screen edits App.settings, so their file is redirected; the
## ways out (main menu, quit) are the test's own.

const PATH := "user://test_pause/settings.cfg"
const ALWAYS_SHOWN: Array[String] = ["resume", "options", "main_menu", "quit"]

var _menu: PauseMenu
var _real_path := ""
var _left := 0
var _quit := 0


func before_each() -> void:
	_real_path = App.settings.path
	App.settings.path = PATH
	_left = 0
	_quit = 0
	_menu = PauseMenu.mount(add_child_autofree(Node.new()))
	_menu.main_menu_action = func() -> void: _left += 1
	_menu.quit_action = func() -> void: _quit += 1


func after_each() -> void:
	get_tree().paused = false
	App.settings.path = _real_path
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH.get_base_dir())


func test_open_pauses_the_tree_and_resume_unpauses_it() -> void:
	watch_signals(_menu)
	assert_false(_menu.is_open())
	_menu.open()
	assert_true(_menu.is_open())
	assert_true(get_tree().paused)
	assert_eq(get_viewport().gui_get_focus_owner(), _button("resume"))
	_button("resume").pressed.emit()
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)
	assert_signal_emit_count(_menu, "resumed", 1)
	_menu.close()
	assert_signal_emit_count(_menu, "resumed", 1, "closing a closed menu reports nothing")


func test_mount_puts_the_menu_on_its_own_layer_that_runs_while_paused() -> void:
	var layer := _menu.get_parent() as CanvasLayer
	assert_eq(layer.layer, PauseMenu.LAYER)
	assert_eq(PauseMenu.LAYER, 50)
	assert_eq(layer.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_eq(_menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_false(_menu.is_open())


func test_focus_returns_to_where_it_was() -> void:
	var before: Button = add_child_autofree(Button.new())
	before.grab_focus()
	_menu.open()
	assert_ne(get_viewport().gui_get_focus_owner(), before)
	_menu.close()
	assert_eq(get_viewport().gui_get_focus_owner(), before)


func test_entries_follow_the_state_source_and_the_leave_text() -> void:
	_menu.open()
	for entry: String in ALWAYS_SHOWN:
		assert_true(_button(entry).visible, entry)
	for entry: String in ["save", "load", "leave"]:
		assert_false(_button(entry).visible, entry)
	assert_false(_hint().visible)
	_menu.close()
	_menu.state_source = func() -> GameState: return GameState.new()
	_menu.leave_text = "RAID_MENU_FLEE"
	_menu.open()
	assert_true(_button("save").visible)
	assert_false(_button("save").disabled)
	assert_false(_hint().visible)
	assert_true(_button("load").visible)
	assert_true(_button("leave").visible)
	assert_eq(_button("leave").text, tr("RAID_MENU_FLEE"))
	_menu.close()
	_menu.state_source = func() -> GameState: return null
	_menu.leave_text = ""
	_menu.open()
	assert_true(_button("save").visible)
	assert_true(_button("save").disabled, "nothing to save right now")
	assert_eq(_button("save").focus_mode, Control.FOCUS_NONE)
	assert_true(_hint().visible)
	assert_eq(_hint().text, tr("PAUSE_SAVE_BLOCKED"))
	assert_true(_button("load").visible, "loading stays possible")
	assert_false(_button("leave").visible)


func test_the_scene_s_own_entry_reports_and_closes() -> void:
	_menu.leave_text = "RAID_MENU_FLEE"
	_menu.open()
	watch_signals(_menu)
	_button("leave").pressed.emit()
	assert_signal_emit_count(_menu, "leave_requested", 1)
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_cancel_closes_a_sub_screen_first_and_then_resumes() -> void:
	_menu.state_source = func() -> GameState: return GameState.new()
	_menu.open()
	_press("ui_cancel")
	assert_true(_menu.is_open(), "the press that opened the menu does not close it again")
	await get_tree().process_frame
	_button("options").pressed.emit()
	var options := _menu.find_child("options_screen", true, false) as OptionsScreen
	assert_true(options.visible)
	assert_false(options.allow_language, "the language only changes in the main menu")
	_press("ui_cancel")
	assert_false(options.visible)
	assert_true(_menu.is_open())
	assert_eq(get_viewport().gui_get_focus_owner(), _button("options"))
	_button("load").pressed.emit()
	assert_true(_slots().visible)
	_press("ui_cancel")
	assert_false(_slots().visible)
	assert_true(_menu.is_open())
	assert_eq(get_viewport().gui_get_focus_owner(), _button("load"))
	_button("quit").pressed.emit()
	assert_true(_dialog().visible)
	_press("ui_cancel")
	assert_false(_dialog().visible)
	assert_true(_menu.is_open())
	assert_true(get_tree().paused)
	_press("ui_cancel")
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_main_menu_and_quit_ask_first() -> void:
	_menu.open()
	_button("main_menu").pressed.emit()
	assert_true(_dialog().visible)
	assert_eq(_question(), tr("PAUSE_ASK_MAIN_MENU"), "nothing to lose without a campaign")
	assert_eq(_left, 0, "not before the player confirmed")
	(_dialog().find_child("cancel", true, false) as Button).pressed.emit()
	assert_false(_dialog().visible)
	assert_eq(_left, 0)
	assert_true(_menu.is_open())
	_button("main_menu").pressed.emit()
	(_dialog().find_child("confirm", true, false) as Button).pressed.emit()
	assert_eq(_left, 1)
	_button("quit").pressed.emit()
	assert_eq(_question(), tr("PAUSE_ASK_QUIT"))
	assert_eq(_quit, 0)
	(_dialog().find_child("confirm", true, false) as Button).pressed.emit()
	assert_eq(_quit, 1)
	assert_eq(_left, 1)


func test_the_question_warns_about_unsaved_progress_in_a_campaign() -> void:
	_menu.state_source = func() -> GameState: return GameState.new()
	_menu.open()
	_button("main_menu").pressed.emit()
	assert_string_contains(_question(), tr("PAUSE_ASK_MAIN_MENU"))
	assert_string_contains(_question(), tr("PAUSE_UNSAVED"))
	(_dialog().find_child("cancel", true, false) as Button).pressed.emit()
	_button("quit").pressed.emit()
	assert_string_contains(_question(), tr("PAUSE_ASK_QUIT"))
	assert_string_contains(_question(), tr("PAUSE_UNSAVED"))


func test_save_and_load_open_the_slots_and_a_picked_save_is_passed_on() -> void:
	_menu.state_source = func() -> GameState: return GameState.new()
	_menu.open()
	watch_signals(_menu)
	_button("save").pressed.emit()
	assert_true(_slots().visible)
	_slots().close()
	assert_eq(get_viewport().gui_get_focus_owner(), _button("save"))
	_button("load").pressed.emit()
	assert_true(_slots().visible)
	_slots().load_requested.emit("slot_2")
	assert_signal_emitted_with_parameters(_menu, "load_requested", ["slot_2"])
	assert_false(_slots().visible)
	assert_false(_menu.is_open())
	assert_false(get_tree().paused)


func test_the_entries_wrap_around_and_keys_never_lead_into_the_scene() -> void:
	_cover_the_viewport_with_buttons()
	_menu.open()
	await get_tree().process_frame
	await get_tree().process_frame
	_press("ui_up")
	assert_eq(get_viewport().gui_get_focus_owner(), _button("quit"))
	_press("ui_focus_next")
	assert_eq(get_viewport().gui_get_focus_owner(), _button("resume"))
	_press("ui_down")
	assert_eq(get_viewport().gui_get_focus_owner(), _button("options"))
	_press("ui_left")
	_press("ui_right")
	_press("ui_right")
	assert_eq(get_viewport().gui_get_focus_owner(), _button("options"))
	_button("quit").pressed.emit()
	var cancel := _dialog().find_child("cancel", true, false) as Button
	var confirm := _dialog().find_child("confirm", true, false) as Button
	assert_eq(get_viewport().gui_get_focus_owner(), cancel, "the harmless answer has focus")
	for action: String in ["ui_up", "ui_down", "ui_left"]:
		_press(action)
		assert_eq(get_viewport().gui_get_focus_owner(), cancel, action)
	_press("ui_right")
	assert_eq(get_viewport().gui_get_focus_owner(), confirm)
	for action: String in ["ui_up", "ui_down", "ui_right"]:
		_press(action)
		assert_eq(get_viewport().gui_get_focus_owner(), confirm, action)
	_press("ui_focus_next")
	assert_eq(get_viewport().gui_get_focus_owner(), cancel)


func test_the_entries_step_aside_while_a_sub_screen_shows() -> void:
	_menu.open()
	_button("options").pressed.emit()
	assert_false(_button("resume").is_visible_in_tree(), "nothing behind the options takes focus")
	_menu.find_child("options_screen", true, false).call("close")
	assert_true(_button("resume").is_visible_in_tree())
	assert_eq(get_viewport().gui_get_focus_owner(), _button("options"))
	_button("quit").pressed.emit()
	assert_false(_button("resume").is_visible_in_tree())
	_menu.close()
	_menu.open()
	assert_true(_button("resume").is_visible_in_tree(), "a new start shows the entries")
	assert_false(_dialog().visible)


func test_a_menu_freed_while_open_does_not_leave_the_tree_paused() -> void:
	var scene: Node = add_child_autofree(Node.new())
	var menu := PauseMenu.mount(scene)
	menu.open()
	assert_true(get_tree().paused)
	scene.free()
	assert_false(get_tree().paused)


## Stands in for the scene behind the menu: wherever Godot looks for a neighbour, one is.
func _cover_the_viewport_with_buttons() -> void:
	var grid: GridContainer = add_child_autofree(GridContainer.new())
	grid.columns = 9
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in 81:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(button)


func _button(button_name: String) -> Button:
	return _menu.find_child(button_name, true, false) as Button


func _hint() -> Label:
	return _menu.find_child("save_hint", true, false) as Label


func _slots() -> SaveSlotsScreen:
	return _menu.find_child("save_slots", true, false) as SaveSlotsScreen


func _dialog() -> ConfirmDialog:
	return _menu.find_child("confirm_dialog", true, false) as ConfirmDialog


func _question() -> String:
	return (_dialog().find_children("*", "Label", true, false)[0] as Label).text


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
