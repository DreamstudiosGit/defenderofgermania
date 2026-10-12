class_name MapCamera
extends Camera3D
## Perspective camera over the map table, tilted down by camera.pitch_deg (data/map_art.json).
## Pans with WASD/arrows, the left stick and a middle- or right-mouse drag, zooms with the
## wheel (towards the cursor), Page Up/Down and the right stick, stays over the realm and
## glides to a province on focus().

## Table point (x, z) in the middle of the view.
var target := Vector2.ZERO
## Distance from the target along the view direction.
var distance: float = 150.0

var _goal := Vector2.ZERO
var _goal_distance: float = 150.0
var _bounds := Rect2()
var _anchors: Dictionary[String, Vector3] = {}
var _ground: float = 0.6
var _pitch: float = deg_to_rad(52.0)
var _dragging: bool = false


## bounds: table area the target stays in; anchors: province centres for focus().
func setup(bounds: Rect2, anchors: Dictionary[String, Vector3], ground_height: float) -> void:
	_bounds = bounds
	_anchors = anchors
	_ground = ground_height
	_pitch = deg_to_rad(_setting("pitch_deg", 52.0))
	fov = _setting("fov", 34.0)
	near = 0.5
	far = 2000.0
	distance = _clamp_distance(_setting("start_distance", 165.0))
	_goal_distance = distance
	target = bounds.get_center()
	_goal = target
	_place()


## Glides to the province and zooms in to at least the focus distance.
func focus(province_id: String) -> void:
	if not _anchors.has(province_id):
		push_error("map camera: unknown province %s" % province_id)
		return
	var anchor := _anchors[province_id]
	_goal = _clamped(Vector2(anchor.x, anchor.z))
	_goal_distance = minf(_goal_distance, _setting("focus_distance", 55.0))


## Glides to a new distance, kept between camera.min_distance and camera.max_distance.
func zoom_to(value: float) -> void:
	_goal_distance = _clamp_distance(value)


## Where the screen position meets the table at field height, or a non-finite vector.
func ground_point(screen_position: Vector2) -> Vector2:
	return table_point(self, screen_position, _ground)


## Where a camera's ray through the screen position meets the plane at `height`, as (x, z);
## non-finite if it misses.
static func table_point(view: Camera3D, screen_position: Vector2, height: float) -> Vector2:
	var origin := view.project_ray_origin(screen_position)
	var normal := view.project_ray_normal(screen_position)
	if normal.y > -0.0001:
		return Vector2(NAN, NAN)
	var hit := origin + normal * ((height - origin.y) / normal.y)
	return Vector2(hit.x, hit.z)


func _process(delta: float) -> void:
	var pan := MapInputMap.pan_vector()
	if pan != Vector2.ZERO:
		var step := pan * _setting("pan_speed", 0.9) * distance * delta
		target = _clamped(target + step)
		_goal = _clamped(_goal + step)
	var zoom := MapInputMap.zoom_axis()
	if zoom != 0.0:
		_goal_distance = _clamp_distance(
			_goal_distance * pow(_setting("zoom_rate", 3.0), -zoom * delta)
		)
	var blend := 1.0 - exp(-_setting("glide_speed", 5.0) * delta)
	target = target.lerp(_goal, blend)
	distance = lerpf(distance, _goal_distance, blend)
	_place()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_towards(_setting("wheel_step", 0.87), button.position)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_towards(1.0 / _setting("wheel_step", 0.87), button.position)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		var before := ground_point(motion.position - motion.relative)
		var after := ground_point(motion.position)
		if before.is_finite() and after.is_finite():
			target = _clamped(target + before - after)
			_goal = target
			_place()


func _zoom_towards(factor: float, screen_position: Vector2) -> void:
	var new_distance := _clamp_distance(_goal_distance * factor)
	var point := ground_point(screen_position)
	if point.is_finite():
		_goal = _clamped(_goal + (point - _goal) * (1.0 - new_distance / _goal_distance))
	_goal_distance = new_distance


func _place() -> void:
	var ground := Vector3(target.x, _ground, target.y)
	position = ground + Vector3(0.0, sin(_pitch), cos(_pitch)) * distance
	rotation = Vector3(-_pitch, 0.0, 0.0)


func _clamped(point: Vector2) -> Vector2:
	return point.clamp(_bounds.position, _bounds.end)


func _clamp_distance(value: float) -> float:
	return clampf(value, _setting("min_distance", 24.0), _setting("max_distance", 175.0))


static func _setting(key: String, fallback: float) -> float:
	return MapArt.number("camera", key, fallback)
