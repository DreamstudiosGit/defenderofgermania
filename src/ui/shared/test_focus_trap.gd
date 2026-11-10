extends GutTest
## FocusTrap: focus that leaves a modal screen while it shows comes back, of two screens the
## one in front holds it, and the helpers spell out the ways between a screen's controls.

var _screen: Control
var _inside: Button
var _outside: Button


func before_each() -> void:
	_outside = add_child_autofree(Button.new())
	_screen = add_child_autofree(Control.new())
	_inside = Button.new()
	_screen.add_child(_inside)
	_screen.add_child(FocusTrap.new())


func after_each() -> void:
	get_tree().paused = false


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


func test_of_two_screens_the_one_in_front_holds_the_focus() -> void:
	_inside.grab_focus()
	var front: Control = add_child_autofree(Control.new())
	var theirs := Button.new()
	front.add_child(theirs)
	front.add_child(FocusTrap.new())
	theirs.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), theirs, "a screen opening in front takes it")
	_inside.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), theirs, "the one behind cannot take it back")
	_outside.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), theirs, "only the one in front fetches it")
	front.visible = false
	_inside.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), _inside)


func test_a_higher_canvas_layer_is_in_front_wherever_it_is_in_the_tree() -> void:
	var layer: CanvasLayer = add_child_autofree(CanvasLayer.new())
	layer.layer = 1
	move_child(layer, 0)
	var above := Control.new()
	layer.add_child(above)
	var theirs := Button.new()
	above.add_child(theirs)
	above.add_child(FocusTrap.new())
	_inside.grab_focus()
	theirs.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), theirs)
	_inside.grab_focus()
	assert_eq(get_viewport().gui_get_focus_owner(), theirs)


func test_the_pause_menu_over_a_scene_s_dialog_holds_the_focus_and_gives_it_back() -> void:
	var dialog: ConfirmDialog = add_child_autofree(ConfirmDialog.new())
	dialog.ask("?", "!")
	var cancel := get_viewport().gui_get_focus_owner()
	var menu := PauseMenu.mount(add_child_autofree(Node.new()))
	menu.open()
	assert_eq(get_viewport().gui_get_focus_owner().name, &"resume")
	for action: String in ["ui_down", "ui_down", "ui_up"]:
		_press(action)
		assert_true(menu.is_ancestor_of(get_viewport().gui_get_focus_owner()), action)
	assert_eq(get_viewport().gui_get_focus_owner().name, &"options")
	menu.close()
	assert_false(get_tree().paused)
	assert_eq(get_viewport().gui_get_focus_owner(), cancel, "back in the dialog")


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
