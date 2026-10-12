class_name SiegeInputReader
extends RefCounted
## One device (keyboard and mouse, or one controller) as aim steps for the trebuchet: a tap
## moves one step, holding repeats after a moment and speeds up; the mouse wheel shifts the
## counterweight (with Shift the angle).

const REPEAT_DELAY := 0.3
const REPEAT_RATE := 10.0
const FAST_AFTER := 1.2
const FAST_RATE := 28.0

var device: int

var _prefix: String
var _held: Dictionary[String, float] = {}
var _direction: Dictionary[String, int] = {}
var _carry: Dictionary[String, float] = {}
var _wheel_weight: int = 0
var _wheel_angle: int = 0


func _init(input_device: int) -> void:
	device = input_device
	_prefix = SiegeInputMap.prefix(device)


func weight_steps(delta: float) -> int:
	var steps := _steps("weight_up", "weight_down", delta) + _wheel_weight
	_wheel_weight = 0
	return steps


func angle_steps(delta: float) -> int:
	var steps := _steps("angle_up", "angle_down", delta) + _wheel_angle
	_wheel_angle = 0
	return steps


func just(action: String) -> bool:
	return Input.is_action_just_pressed(_prefix + action)


func held(action: String) -> bool:
	return Input.is_action_pressed(_prefix + action)


func handle_event(event: InputEvent) -> void:
	if device != BattleInputMap.Device.KEYBOARD:
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	var step := 0
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = 1
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = -1
	if button.shift_pressed:
		_wheel_angle += step
	else:
		_wheel_weight += step


func _steps(up: String, down: String, delta: float) -> int:
	var direction := int(held(up)) - int(held(down))
	if direction == 0:
		_held.erase(up)
		return 0
	if not _held.has(up) or _direction.get(up, 0) != direction:
		_held[up] = 0.0
		_direction[up] = direction
		_carry[up] = 0.0
		return direction
	var time: float = _held[up] + delta
	_held[up] = time
	if time < REPEAT_DELAY:
		return 0
	var rate := REPEAT_RATE if time < FAST_AFTER else FAST_RATE
	var carry: float = _carry[up] + rate * delta
	var steps := floori(carry)
	_carry[up] = carry - steps
	return steps * direction
