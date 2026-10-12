class_name MerchantInputReader
extends RefCounted
## Turns the raider's devices (keyboard and mouse, controllers) into MerchantInputs: several
## devices may steer the one leader. Presses are polled every frame and latched until the next
## simulation tick takes them.

var devices := PackedInt32Array()

var _prefixes := PackedStringArray()
var _pending := MerchantInput.new()


func _init(input_devices: PackedInt32Array) -> void:
	for device: int in input_devices:
		if device >= 0:
			devices.append(device)
			_prefixes.append(MerchantInputMap.prefix(device))


func is_empty() -> bool:
	return devices.is_empty()


func poll() -> void:
	_pending.strike = _pending.strike or _just("strike")
	_pending.parry = _pending.parry or _just("parry")
	_pending.shoot = _pending.shoot or _just("shoot")


func take() -> MerchantInput:
	var input := _pending
	_pending = MerchantInput.new()
	for prefix: String in _prefixes:
		input.move += Input.get_axis(prefix + "left", prefix + "right")
		input.pull = input.pull or Input.is_action_pressed(prefix + "pull")
	input.move = clampf(input.move, -1.0, 1.0)
	return input


func menu_pressed() -> bool:
	return _just("menu")


## The keyboard device, else the first controller: which hints the HUD shows.
func main_device() -> int:
	return devices[0] if not devices.is_empty() else -1


func _just(action: String) -> bool:
	for prefix: String in _prefixes:
		if Input.is_action_just_pressed(prefix + action):
			return true
	return false
