extends GutTest
## Waiting for a new binding: the next key or mouse button (keyboard family) or the next
## button, stick or trigger (controller family) is reported as a token, everything is
## swallowed meanwhile, Esc and waiting cancel, and the screen leaves by itself.

const KEYS := InputTable.Family.KEYS
const PAD := InputTable.Family.PAD

var _capture: BindingCapture


func after_each() -> void:
	App.pad_in_use = false


func test_the_next_key_is_captured_by_its_position() -> void:
	_wait_for(KEYS)
	_push(_key(KEY_F, false), "a release is not a choice")
	_push(_key(KEY_F, true, true), "nor is a key that repeats")
	assert_signal_emit_count(_capture, "captured", 0)
	var german := _key(KEY_Y)
	german.keycode = KEY_Z
	_push(german)
	assert_signal_emitted_with_parameters(_capture, "captured", ["key:Y"])
	assert_false(_capture.visible)


func test_a_mouse_button_is_captured_and_the_wheel_is_not() -> void:
	_wait_for(KEYS)
	_push(_click(MOUSE_BUTTON_LEFT), "the second click of a double click is not a choice")
	_capture.tick(BindingCapture.MOUSE_GUARD)
	_push(_click(MOUSE_BUTTON_WHEEL_DOWN))
	assert_signal_emit_count(_capture, "captured", 0)
	_push(_click(MOUSE_BUTTON_RIGHT))
	assert_signal_emitted_with_parameters(_capture, "captured", ["mouse:right"])


func test_escape_and_controller_b_cancel_a_keyboard_capture() -> void:
	_wait_for(KEYS)
	_push(_button(JOY_BUTTON_X), "a controller button is no key")
	assert_signal_emit_count(_capture, "cancelled", 0)
	_push(_key(KEY_ESCAPE))
	assert_signal_emit_count(_capture, "cancelled", 1)
	assert_signal_emit_count(_capture, "captured", 0)
	_wait_for(KEYS)
	_push(_button(JOY_BUTTON_B))
	assert_signal_emit_count(_capture, "cancelled", 1)


func test_a_controller_button_is_captured_also_b() -> void:
	_wait_for(PAD)
	_push(_key(KEY_F), "a key is no controller button")
	assert_signal_emit_count(_capture, "captured", 0)
	_push(_button(JOY_BUTTON_B, 1))
	assert_signal_emitted_with_parameters(_capture, "captured", ["pad:b"])


func test_a_strong_push_of_a_stick_or_trigger_is_captured() -> void:
	_wait_for(PAD)
	_push(_axis(JOY_AXIS_LEFT_Y, -0.4), "a weak push is not")
	assert_signal_emit_count(_capture, "captured", 0)
	_push(_axis(JOY_AXIS_LEFT_Y, -0.9))
	assert_signal_emitted_with_parameters(_capture, "captured", ["axis:left_y-"])
	_wait_for(PAD)
	_push(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_signal_emitted_with_parameters(_capture, "captured", ["axis:rt"])
	_wait_for(KEYS)
	_push(_axis(JOY_AXIS_LEFT_Y, -0.9), "the keyboard takes no stick")
	assert_signal_emit_count(_capture, "captured", 0)


func test_a_stick_held_when_the_wait_begins_counts_after_it_rested() -> void:
	_wait_for(PAD)
	_capture._held[Vector2i(0, JOY_AXIS_RIGHT_X)] = true
	_push(_axis(JOY_AXIS_RIGHT_X, 0.9))
	assert_signal_emit_count(_capture, "captured", 0)
	_push(_axis(JOY_AXIS_RIGHT_X, 0.1))
	_push(_axis(JOY_AXIS_RIGHT_X, 0.9))
	assert_signal_emitted_with_parameters(_capture, "captured", ["axis:right_x+"])


func test_escape_and_a_click_cancel_a_controller_capture() -> void:
	_wait_for(PAD)
	_push(_key(KEY_ESCAPE))
	assert_signal_emit_count(_capture, "cancelled", 1)
	_wait_for(PAD)
	_push(_click(MOUSE_BUTTON_LEFT))
	assert_signal_emit_count(_capture, "cancelled", 1)


func test_waiting_cancels_and_the_countdown_shows() -> void:
	_wait_for(PAD)
	var countdown := _capture.find_child("countdown", true, false) as Label
	assert_eq(countdown.text, tr("INPUT_CAPTURE_CANCEL_PAD") % 5)
	_capture.tick(1.5)
	assert_eq(countdown.text, tr("INPUT_CAPTURE_CANCEL_PAD") % 4)
	assert_signal_emit_count(_capture, "cancelled", 0)
	_capture.tick(BindingCapture.TIMEOUT)
	assert_signal_emit_count(_capture, "cancelled", 1)
	assert_false(_capture.visible)


func test_it_swallows_input_until_it_has_left() -> void:
	_wait_for(PAD)
	_push(_button(JOY_BUTTON_X))
	_push(_axis(JOY_AXIS_LEFT_Y, -0.9), "what follows the capture reaches nobody either")
	_push(_button(JOY_BUTTON_Y))
	assert_signal_emit_count(_capture, "captured", 1, "and is not captured again")
	assert_false(_capture.is_queued_for_deletion())
	_capture.tick(BindingCapture.SETTLE)
	assert_true(_capture.is_queued_for_deletion())


func _wait_for(family: InputTable.Family) -> void:
	_capture = add_child_autofree(BindingCapture.new(family, "Battle · Attack", "Space"))
	watch_signals(_capture)


## Every event is swallowed while the capture is in the tree.
func _push(event: InputEvent, why: String = "") -> void:
	get_viewport().push_input(event)
	assert_true(get_viewport().is_input_handled(), why)


## A key as the keyboard sends it on a US layout: its position and its label.
func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _click(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _button(button: JoyButton, joypad: int = 0) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = joypad
	event.button_index = button
	event.pressed = true
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
