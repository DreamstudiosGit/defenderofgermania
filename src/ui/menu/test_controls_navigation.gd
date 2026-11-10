extends GutTest
## The controls tab with keys and a controller alone: up and down walk the list in its two
## columns, the edges hold, the ways in and out lead to the tab bar and the back button,
## focus never leaves the screen, and the list scrolls the focused line into view together
## with the fixed rows and headings around it. The options are the test's own file.

const SETTINGS := "user://test_controls_navigation/settings.cfg"
const KEYS := InputTable.Family.KEYS
const PAD := InputTable.Family.PAD

var _locale_before: String
var _screen: OptionsScreen
var _section: ControlsSection


func before_all() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func before_each() -> void:
	_screen = add_child_autofree(OptionsScreen.new())
	_screen.settings = UserSettings.new()
	_screen.settings.path = SETTINGS
	_screen.open()
	_press("ui_page_up")
	_section = _screen.find_children("*", "ControlsSection", true, false)[0] as ControlsSection


func after_each() -> void:
	DirAccess.remove_absolute(SETTINGS)
	DirAccess.remove_absolute(SETTINGS.get_base_dir())


func after_all() -> void:
	TranslationServer.set_locale(_locale_before)


func test_left_and_right_stay_in_the_line_and_up_leads_to_the_tabs() -> void:
	var bar := (_screen.find_child("tabs", true, false) as TabContainer).get_tab_bar()
	assert_eq(_focused(), _cell("map", "up", KEYS), "focus starts on the first binding")
	_press("ui_left")
	assert_eq(_focused(), _cell("map", "up", KEYS), "the left edge holds")
	_press("ui_right")
	assert_eq(_focused(), _cell("map", "up", PAD))
	_press("ui_right")
	assert_eq(_focused(), _cell("map", "up", PAD), "the right edge holds")
	_press("ui_up")
	assert_eq(_focused(), bar)
	_press("ui_down")
	assert_eq(_focused(), _cell("map", "up", KEYS))


func test_up_and_down_keep_the_column_where_the_next_line_has_one() -> void:
	_cell("map", "zoom_out", KEYS).grab_focus()
	_press("ui_down")
	assert_eq(_focused(), _button("reset_map"), "a line with one control takes both columns")
	_press("ui_down")
	assert_eq(_focused(), _cell("castle", "orbit_left", PAD))
	_press("ui_up")
	_press("ui_up")
	assert_eq(_focused(), _cell("map", "zoom_out", PAD))
	_cell("joust", "strike", KEYS).grab_focus()
	_press("ui_down")
	assert_eq(_focused(), _cell("joust", "aim_up", PAD), "only the controller aims the lance")
	_press("ui_left")
	assert_eq(_focused(), _cell("joust", "aim_up", PAD))
	_cell("battle", "group_next", PAD).grab_focus()
	_press("ui_down")
	assert_eq(_focused(), _cell("battle", "slot_1", KEYS), "a controller has no group slots")


func test_down_walks_every_line_to_the_back_button_and_never_leaves_the_screen() -> void:
	_cover_the_viewport_with_buttons()
	await _settle()
	var steps := 0
	while _focused() != _button("reset_all") and steps < 200:
		_press("ui_down")
		steps += 1
		assert_true(_screen.is_ancestor_of(_focused()), "down led to %s" % _focused().name)
	assert_eq(steps, 64, "every line that takes focus, then the button below the list")
	_press("ui_left")
	_press("ui_right")
	assert_eq(_focused(), _button("reset_all"))
	_press("ui_down")
	assert_eq(_focused(), _button("back"))
	_press("ui_up")
	assert_eq(_focused(), _button("reset_all"))
	_press("ui_up")
	assert_eq(_focused(), _button("reset_merchant"))


func test_the_focused_line_scrolls_into_view_with_the_rows_around_it() -> void:
	await _settle()
	var list := _section.find_child("list", true, false) as ScrollContainer
	assert_true(_is_in_view(list, _row("map", "up")))
	assert_eq(list.scroll_vertical, 0, "the fixed rows above the first binding stay in view")
	var reset := _button("reset_battle")
	reset.grab_focus()
	await _settle()
	assert_true(_is_in_view(list, reset))
	assert_true(_is_in_view(list, _row("battle", "menu")), "the fixed rows above it came along")
	assert_false(_is_in_view(list, _row("map", "up")))
	_cell("joust", "spur", KEYS).grab_focus()
	await _settle()
	var heading := list.get_child(0).get_child(_row("joust", "spur").get_index() - 1) as Label
	assert_eq(heading.text, "Joust")
	assert_true(_is_in_view(list, heading), "and so did the heading")
	_cell("map", "up", PAD).grab_focus()
	await _settle()
	assert_eq(list.scroll_vertical, 0, "back at the top the fixed rows show again")


func test_the_section_works_outside_the_options() -> void:
	_screen.close()
	var section: ControlsSection = add_child_autofree(ControlsSection.new())
	section.refresh()
	var first := section.find_child("map_up", true, false).get_node("keys") as Button
	first.grab_focus()
	_press("ui_up")
	assert_eq(_focused(), first, "without a tab bar above, focus stays")
	var reset := section.find_child("reset_all", true, false) as Button
	reset.grab_focus()
	_press("ui_down")
	assert_eq(_focused(), reset)


func _row(scene: String, action: String) -> ControlsRow:
	return _section.find_child("%s_%s" % [scene, action], true, false) as ControlsRow


func _cell(scene: String, action: String, family: InputTable.Family) -> Button:
	return _row(scene, action).cells[family]


func _button(button_name: String) -> Button:
	return _screen.find_child(button_name, true, false) as Button


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _settle() -> void:
	for frame: int in 3:
		await get_tree().process_frame


func _is_in_view(list: ScrollContainer, control: Control) -> bool:
	return list.get_global_rect().grow(1.0).encloses(control.get_global_rect())


## Stands in for the screen behind the modal: wherever Godot looks for a neighbour, one is.
func _cover_the_viewport_with_buttons() -> void:
	var grid: GridContainer = add_child_autofree(GridContainer.new())
	grid.columns = 9
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in 81:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(button)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
