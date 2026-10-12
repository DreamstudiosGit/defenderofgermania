class_name RaidInputReader
extends RefCounted
## Turns one device (keyboard and mouse, or one controller) into RaidInputs. Strike and parry
## presses are latched until the next simulation tick takes them; their height is the one held
## when the button went down (mouse: where the pointer is on the leader's body).

## Pointer above this share of the leader's screen height aims high, below the second low.
const HIGH_SHARE := 0.36
const LOW_SHARE := 0.64

var device: int

var _prefix: String
var _pending := RaidInput.new()


func _init(input_device: int) -> void:
	device = input_device
	_prefix = RaidInputMap.prefix(device)


## Height held right now (RaidFighter.Height); nothing or both held is the middle.
func held_height() -> int:
	var up := Input.is_action_pressed(_prefix + "high")
	var down := Input.is_action_pressed(_prefix + "low")
	if up and not down:
		return RaidFighter.Height.HIGH
	if down and not up:
		return RaidFighter.Height.LOW
	return RaidFighter.Height.MID


func poll() -> void:
	if _just("parry"):
		_pending.parry = held_height()
	elif _just("strike"):
		_pending.strike = held_height()


## Mouse of the keyboard player: left button strikes, right button parries. Up / down held win
## over the pointer; otherwise the pointer's height on the leader (screen y of head top and
## feet) picks the height.
func handle_event(event: InputEvent, leader_top: float, leader_bottom: float) -> void:
	if device != BattleInputMap.Device.KEYBOARD:
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	var height := held_height()
	var keys_held := (
		Input.is_action_pressed(_prefix + "high") or Input.is_action_pressed(_prefix + "low")
	)
	if not keys_held and leader_bottom > leader_top:
		var share := (button.position.y - leader_top) / (leader_bottom - leader_top)
		height = (
			RaidFighter.Height.HIGH if share < HIGH_SHARE
			else RaidFighter.Height.LOW if share > LOW_SHARE
			else RaidFighter.Height.MID
		)
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			_pending.strike = height
		MOUSE_BUTTON_RIGHT:
			_pending.parry = height


func take() -> RaidInput:
	var input := _pending
	input.move = Input.get_axis(_prefix + "left", _prefix + "right")
	input.act = Input.is_action_pressed(_prefix + "act")
	_pending = RaidInput.new()
	return input


func menu_pressed() -> bool:
	return _just("menu")


func _just(action: String) -> bool:
	return Input.is_action_just_pressed(_prefix + action)
