extends GutTest
## FocusTrap: focus that leaves a modal screen while it shows comes back, and the helpers
## spell out the ways between a screen's controls.

var _screen: Control
var _inside: Button
var _outside: Button


func before_each() -> void:
	_outside = add_child_autofree(Button.new())
	_screen = add_child_autofree(Control.new())
	_inside = Button.new()
	_screen.add_child(_inside)
	_screen.add_child(FocusTrap.new())


func test_focus_that_leaves_a_showing_screen_returns() -> void:
	_inside.grab_focus()
	_outside.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), _inside)


func test_a_hidden_screen_lets_focus_go() -> void:
	_inside.grab_focus()
	_screen.visible = false
	_outside.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), _outside)
	_screen.visible = true
	assert_eq(get_viewport().gui_get_focus_owner(), _outside, "showing alone takes no focus")


func test_two_screens_side_by_side_do_not_pull_focus_back_and_forth() -> void:
	var other: Control = add_child_autofree(Control.new())
	var theirs := Button.new()
	other.add_child(theirs)
	other.add_child(FocusTrap.new())
	theirs.grab_focus()
	_inside.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), theirs, "focus stays where it is, once")
	other.visible = false
	_inside.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), _inside)


func test_focusables_lists_what_can_take_focus_in_tree_order() -> void:
	var box := VBoxContainer.new()
	_screen.add_child(box)
	var nested := Button.new()
	box.add_child(nested)
	var hidden := Button.new()
	hidden.visible = false
	box.add_child(hidden)
	var locked := Button.new()
	locked.focus_mode = Control.FOCUS_NONE
	box.add_child(locked)
	box.add_child(Label.new())
	var expected: Array[Control] = [_inside, nested]
	assert_eq(FocusTrap.focusables(_screen), expected)


func test_a_linked_column_passes_over_a_control_that_cannot_take_focus() -> void:
	var column: Array[Control] = [_inside]
	for index: int in 3:
		var button := Button.new()
		_screen.add_child(button)
		column.append(button)
	FocusTrap.link_column(column)
	column[1].focus_mode = Control.FOCUS_NONE
	_inside.grab_focus()
	_press("ui_up")
	assert_eq(get_viewport().gui_get_focus_owner(), _inside, "the ends stay put")
	_press("ui_down")
	assert_eq(get_viewport().gui_get_focus_owner(), column[2])
	_press("ui_down")
	_press("ui_down")
	assert_eq(get_viewport().gui_get_focus_owner(), column[3])
	FocusTrap.link_column(column, true)
	_press("ui_down")
	assert_eq(get_viewport().gui_get_focus_owner(), _inside, "wrapped")
	FocusTrap.pin(_inside, [SIDE_LEFT, SIDE_RIGHT])
	_press("ui_left")
	_press("ui_right")
	assert_eq(get_viewport().gui_get_focus_owner(), _inside)
	FocusTrap.ring(_inside, column[3])
	_press("ui_focus_prev")
	assert_eq(get_viewport().gui_get_focus_owner(), column[3])
	_press("ui_focus_next")
	assert_eq(get_viewport().gui_get_focus_owner(), _inside)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
