class_name CastleCamera
extends Camera3D
## Orbit camera of the castle view ("camera" in data/castle_art.json): turns and tilts with a
## mouse drag, the right stick or WASD, zooms with the wheel, Page Up/Down or the triggers, and
## circles slowly on its own while nobody touches it.

var yaw: float = 0.0
var pitch: float = 0.5
var distance: float = 90.0

var _goal_yaw: float = 0.0
var _goal_pitch: float = 0.5
var _goal_distance: float = 90.0
var _target := Vector3.ZERO
var _idle: float = 0.0
var _dragging: bool = false


## Back to the opening view.
func reset() -> void:
	fov = _setting("fov", 36.0)
	near = 0.5
	far = 1500.0
	_target = CastleArt.vector(CastleArt.section("camera").get("target"), Vector3(0, 6, 0))
	yaw = deg_to_rad(_setting("yaw_deg", 24.0))
	pitch = deg_to_rad(_setting("pitch_deg", 30.0))
	distance = _setting("distance", 90.0)
	_goal_yaw = yaw
	_goal_pitch = pitch
	_goal_distance = distance
	_idle = 0.0
	_place()


## Jumps to an orbit position (degrees, metres) without gliding.
func frame(yaw_deg: float, pitch_deg: float, to_distance: float) -> void:
	yaw = deg_to_rad(yaw_deg)
	pitch = _clamp_pitch(deg_to_rad(pitch_deg))
	distance = to_distance
	_goal_yaw = yaw
	_goal_pitch = pitch
	_goal_distance = distance
	_place()


## Mouse input forwarded by the view: drags orbit, the wheel zooms.
func handle_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(_setting("wheel_step", 0.88))
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / _setting("wheel_step", 0.88))
		_idle = 0.0
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		var step := deg_to_rad(_setting("drag_deg_per_pixel", 0.3))
		_goal_yaw -= motion.relative.x * step
		_goal_pitch = _clamp_pitch(_goal_pitch + motion.relative.y * step)
		_idle = 0.0


func _process(delta: float) -> void:
	advance(delta)


## Moves the camera on by `delta` seconds: input, idle circling and gliding to the goal.
func advance(delta: float) -> void:
	var orbit := CastleInputMap.orbit_vector()
	var zoom := CastleInputMap.zoom_axis()
	if orbit != Vector2.ZERO or zoom != 0.0 or _dragging:
		_idle = 0.0
	else:
		_idle += delta
	var speed := deg_to_rad(_setting("stick_speed_deg", 80.0))
	_goal_yaw -= orbit.x * speed * delta
	_goal_pitch = _clamp_pitch(_goal_pitch + orbit.y * speed * 0.6 * delta)
	if zoom != 0.0:
		_zoom(pow(_setting("zoom_rate", 2.5), -zoom * delta))
	if _idle > _setting("idle_delay", 4.0):
		_goal_yaw += deg_to_rad(_setting("idle_speed_deg", 2.5)) * delta
	var blend := 1.0 - exp(-_setting("glide_speed", 6.0) * delta)
	yaw = lerpf(yaw, _goal_yaw, blend)
	pitch = lerpf(pitch, _goal_pitch, blend)
	distance = lerpf(distance, _goal_distance, blend)
	_place()


func _zoom(factor: float) -> void:
	_goal_distance = clampf(
		_goal_distance * factor, _setting("min_distance", 30.0), _setting("max_distance", 170.0)
	)


func _place() -> void:
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	transform = Transform3D(Basis.looking_at(-offset, Vector3.UP), _target + offset)


func _clamp_pitch(value: float) -> float:
	return clampf(
		value, deg_to_rad(_setting("min_pitch_deg", 10.0)), deg_to_rad(_setting("max_pitch_deg", 70.0))
	)


static func _setting(key: String, fallback: float) -> float:
	return CastleArt.number("camera", key, fallback)
