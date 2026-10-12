class_name SiegeAimControl
extends RefCounted
## The player's hands on the trebuchet: one reader per device turns keys, sticks and the wheel
## into the aim, and the HUD's sliders and buttons edit the same aim. The rules never trust it:
## TrebuchetSim clamps whatever is thrown.

var aim := TrebuchetShot.new()
var readers: Array[SiegeInputReader] = []
## Whether a "look at the castle" button is held this frame.
var looking: bool = false

var _cfg: SiegeConfig


## devices are BattleInputMap.Device values; negative entries (the computer) are skipped.
func _init(cfg: SiegeConfig, devices: PackedInt32Array) -> void:
	_cfg = cfg
	for device: int in devices:
		if device >= 0:
			readers.append(SiegeInputReader.new(device))
	reset()


func is_human() -> bool:
	return not readers.is_empty()


func reset() -> void:
	aim = TrebuchetShot.make(_cfg.start_counterweight, _cfg.start_angle)
	looking = false


func set_aim(weight: int, angle: int) -> void:
	aim.counterweight = clampi(weight, _cfg.counterweight_min, _cfg.counterweight_max)
	aim.angle = clampi(angle, _cfg.angle_min, _cfg.angle_max)


func set_projectile(kind: TrebuchetShot.Projectile) -> void:
	aim.projectile = kind


func toggle_projectile() -> void:
	var stone := aim.projectile == TrebuchetShot.Projectile.STONE
	set_projectile(TrebuchetShot.Projectile.FIRE_POT if stone else TrebuchetShot.Projectile.STONE)


## Reads every device for one frame of aiming; true when the player lets the arm go.
func poll(delta: float) -> bool:
	var weight := 0
	var angle := 0
	var fire := false
	looking = false
	for reader: SiegeInputReader in readers:
		weight += reader.weight_steps(delta)
		angle += reader.angle_steps(delta)
		if reader.just("projectile"):
			toggle_projectile()
		fire = fire or reader.just("fire")
		looking = looking or reader.held("look")
	if weight != 0 or angle != 0:
		set_aim(aim.counterweight + weight, aim.angle + angle)
	return fire


func menu_pressed() -> bool:
	for reader: SiegeInputReader in readers:
		if reader.just("menu"):
			return true
	return false


func handle_event(event: InputEvent) -> void:
	for reader: SiegeInputReader in readers:
		reader.handle_event(event)


## Control hints for the keyboard and for every controller that is plugged in.
func hints() -> String:
	var keys := PackedStringArray()
	for reader: SiegeInputReader in readers:
		var pad := reader.device != BattleInputMap.Device.KEYBOARD
		var index := reader.device - BattleInputMap.Device.PAD_1
		if pad and readers.size() > 1 and not Input.get_connected_joypads().has(index):
			continue
		keys.append(TranslationServer.translate(
			"SIEGE_HINT_PAD" if pad else "SIEGE_HINT_KEYBOARD"
		))
	return "\n".join(keys)
