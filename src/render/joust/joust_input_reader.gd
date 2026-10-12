class_name JoustInputReader
extends RefCounted
## Turns one device into JoustInputs. Presses are stamped with the simulation time of the frame
## that saw them and handed to the tick containing that moment, so the hit window is judged to
## the frame rather than to the 33 ms tick. The mouse points where the lance hand should go on
## the opponent; a stick moves that point.

## Metres per second the stick moves the hand's goal.
const STICK_SPEED := 1.6

var device: int

var _prefix: String
var _spur_at: float = -1.0
var _strike_at: float = -1.0
var _goal := Vector2.ZERO
var _cursor := Vector2.ZERO
var _has_cursor: bool = false
var _screen_center := Vector2.ZERO
var _pixels_per_metre: float = 0.0


func _init(input_device: int) -> void:
	device = input_device
	_prefix = JoustInputMap.prefix(device)


## Latches this frame's presses at the simulation time `now` (seconds since the joust began).
func poll(now: float) -> void:
	if _just("spur"):
		_spur_at = now
	if _just("strike") and _strike_at < 0.0:
		_strike_at = now


func handle_event(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if device == BattleInputMap.Device.KEYBOARD and motion != null:
		_cursor = motion.position
		_has_cursor = true


## Where the opponent's chest is on screen and how many pixels a metre there spans.
func set_screen_frame(center: Vector2, pixels_per_metre: float) -> void:
	_screen_center = center
	_pixels_per_metre = pixels_per_metre


## The stick starts each aim from the lance's rest.
func begin_aim(rest: Vector2) -> void:
	_goal = rest


## The hand's goal in metres of the target plane (for the HUD).
func goal() -> Vector2:
	return _goal


func take(tick_start: float, dt: float, aim_range: float) -> JoustInput:
	var input := JoustInput.new()
	if device == BattleInputMap.Device.KEYBOARD:
		if _has_cursor and _pixels_per_metre > 0.0:
			var offset := (_cursor - _screen_center) / _pixels_per_metre
			_goal = Vector2(offset.x, -offset.y)
	else:
		_goal += _vector("aim") * STICK_SPEED * dt
	_goal = _goal.clamp(-Vector2.ONE * aim_range, Vector2.ONE * aim_range)
	input.aim = _goal / aim_range
	input.shield = _vector("shield")
	input.spur = _fraction(_spur_at, tick_start, dt)
	if input.spur >= 0.0:
		_spur_at = -1.0
	input.strike = _fraction(_strike_at, tick_start, dt)
	if input.strike >= 0.0:
		_strike_at = -1.0
	return input


func menu_pressed() -> bool:
	return _just("menu")


func _vector(action: String) -> Vector2:
	return Input.get_vector(
		_prefix + action + "_left", _prefix + action + "_right",
		_prefix + action + "_down", _prefix + action + "_up"
	)


## Share of the tick at which a latched press happened, or no press if it belongs to a later tick.
static func _fraction(at: float, tick_start: float, dt: float) -> float:
	if at < 0.0 or at >= tick_start + dt:
		return JoustInput.NO_PRESS
	return clampf((at - tick_start) / dt, 0.0, 1.0)


func _just(action: String) -> bool:
	return Input.is_action_just_pressed(_prefix + action)
