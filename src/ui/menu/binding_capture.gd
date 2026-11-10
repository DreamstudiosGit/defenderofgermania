class_name BindingCapture
extends Control
## Waits for the input the player wants on an action: a key or mouse button for the keyboard
## family, a button, stick or trigger for the controllers. While it waits no input reaches
## the screen behind it. Esc cancels, and so does waiting: a controller has no button left
## that could, since every one of them is a candidate. It frees itself when it is done.

signal captured(token: String)
signal cancelled

const TIMEOUT := 5.0
## A stick or trigger counts once it is pushed this far …
const AXIS_PUSHED := 0.6
## … after it rested below this, so one that is held when the wait begins is not taken.
const AXIS_REST := 0.3
## Input stays swallowed this long after the capture: the stick that was just bound would
## move the focus as well.
const SETTLE := 0.25
## A mouse button counts only this long after the wait began: the second click of a double
## click on the binding is not a choice.
const MOUSE_GUARD := 0.3
const WIDTH := 400.0

var _family: InputTable.Family
var _left := TIMEOUT
var _waited := 0.0
var _done := false
## Sticks and triggers away from their rest: Vector2i(joypad, axis).
var _held: Dictionary[Vector2i, bool] = {}
var _countdown := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)


## `heading` names the scene and action, `current` the binding it has (both translated).
func _init(family: InputTable.Family, heading: String, current: String) -> void:
	_family = family
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := CampaignStyle.modal(self, Color(UiPalette.SHADE, 0.7))
	column.add_child(CampaignStyle.title(tr("INPUT_CAPTURE_TITLE"), 26))
	var pad := family == InputTable.Family.PAD
	var lines: Array[Label] = [
		CampaignStyle.heading(heading, 18),
		CampaignStyle.paragraph(
			tr("INPUT_CAPTURE_PAD") if pad else tr("INPUT_CAPTURE_KEYS"), CampaignStyle.FONT_SIZE
		),
		CampaignStyle.label(
			tr("INPUT_CAPTURE_CURRENT") % current, CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED
		),
		_countdown,
	]
	lines[1].add_theme_color_override("font_color", CampaignStyle.TEXT)
	for line: Label in lines:
		line.custom_minimum_size.x = WIDTH
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(line)
	_countdown.name = "countdown"
	_show_countdown()


func _ready() -> void:
	for joypad: int in Input.get_connected_joypads():
		for axis: int in JOY_AXIS_MAX:
			if absf(Input.get_joy_axis(joypad, axis as JoyAxis)) >= AXIS_REST:
				_held[Vector2i(joypad, axis)] = true


func _process(delta: float) -> void:
	tick(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return
	get_viewport().set_input_as_handled()
	if _done or event.is_echo():
		return
	var motion := event as InputEventJoypadMotion
	if motion != null:
		_on_axis(motion)
	elif event.is_pressed():
		_on_press(event)


## Lets time pass: the wait ends by itself (also when the screen it belongs to is hidden),
## and the screen leaves a moment after it is done.
func tick(seconds: float) -> void:
	_left -= seconds
	_waited += seconds
	if _done:
		if _left <= 0.0:
			queue_free()
	elif _left <= 0.0 or not is_visible_in_tree():
		_finish("")
	else:
		_show_countdown()


func _on_press(event: InputEvent) -> void:
	var from_pad := event is InputEventJoypadButton
	var key := event as InputEventKey
	var escape := key != null and KEY_ESCAPE in [key.physical_keycode, key.keycode]
	if _family == InputTable.Family.PAD:
		if from_pad:
			_take(event)
		elif escape or event is InputEventMouseButton:
			_finish("")
	elif escape or event.is_action_pressed(&"ui_cancel"):
		_finish("")
	elif not from_pad and (key != null or _waited >= MOUSE_GUARD):
		_take(event)


func _on_axis(motion: InputEventJoypadMotion) -> void:
	var id := Vector2i(motion.device, motion.axis)
	var push := absf(motion.axis_value)
	if push < AXIS_REST:
		_held.erase(id)
	elif push >= AXIS_PUSHED and not _held.has(id) and _family == InputTable.Family.PAD:
		_take(motion)


## Events the notation cannot write (the wheel, keys without a name) are waited out.
func _take(event: InputEvent) -> void:
	var token := InputNotation.token(event)
	if not token.is_empty():
		_finish(token)


func _finish(token: String) -> void:
	_done = true
	_left = SETTLE
	visible = false
	if token.is_empty():
		cancelled.emit()
	else:
		captured.emit(token)


func _show_countdown() -> void:
	var pad := _family == InputTable.Family.PAD
	var text := tr("INPUT_CAPTURE_CANCEL_PAD") if pad else tr("INPUT_CAPTURE_CANCEL_KEYS")
	_countdown.text = text % ceili(_left)
