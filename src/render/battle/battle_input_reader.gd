class_name BattleInputReader
extends RefCounted
## Turns one device (keyboard and mouse, or one controller) into BattleInputs. Presses are
## polled every frame and latched until the next simulation tick takes them.

var device: int

var _prefix: String
var _pending := BattleInput.new()
var _zoom: int = 0


func _init(input_device: int) -> void:
	device = input_device
	_prefix = BattleInputMap.prefix(device)


func poll() -> void:
	if _just("group_prev"):
		_pending.group_step = -1
	if _just("group_next"):
		_pending.group_step = 1
	if device == BattleInputMap.Device.KEYBOARD:
		for slot: int in BattleInputMap.SLOTS:
			if _just("slot_%d" % (slot + 1)):
				_pending.group_slot = slot
	_pending.attack = _pending.attack or _just("attack")
	_pending.formation = _pending.formation or _just("formation")
	_pending.rally = _pending.rally or _just("rally")
	if _just("zoom_in"):
		_zoom = -1
	if _just("zoom_out"):
		_zoom = 1


## Mouse commands of the keyboard player: right-click and wheel.
func handle_event(event: InputEvent, camera: Camera3D) -> void:
	if device != BattleInputMap.Device.KEYBOARD:
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	match button.button_index:
		MOUSE_BUTTON_RIGHT:
			var point := BattleCamera.field_point(camera, button.position)
			if point.is_finite():
				_pending.command_point = true
				_pending.point = point
		MOUSE_BUTTON_WHEEL_UP:
			_zoom = -1
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = 1


func take() -> BattleInput:
	var input := _pending
	input.move = Input.get_vector(
		_prefix + "left", _prefix + "right", _prefix + "up", _prefix + "down"
	)
	_pending = BattleInput.new()
	return input


## -1 zoom in, +1 zoom out, 0 nothing; cleared by reading.
func take_zoom() -> int:
	var step := _zoom
	_zoom = 0
	return step


func menu_pressed() -> bool:
	return _just("menu")


func _just(action: String) -> bool:
	return Input.is_action_just_pressed(_prefix + action)
