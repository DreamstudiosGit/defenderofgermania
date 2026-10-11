class_name BattleCamera
extends Camera3D
## Bird's-eye battle camera: tilted 60 degrees, never rotated, two zoom levels, smoothly
## following a focus point on the field (field x = world X, field y = world Z).

const PITCH := 1.0471975512
const NEAR_DISTANCE := 90.0
const FAR_DISTANCE := 210.0
const FOLLOW_RATE := 2.5
const ZOOM_RATE := 4.0
const FIELD_OF_VIEW := 40.0

var zoomed_out: bool = true

var _field := Vector2.ZERO
var _focus := Vector3.ZERO
var _distance := NEAR_DISTANCE


func setup(field_size: Vector2, focus: Vector2) -> void:
	_field = field_size
	fov = FIELD_OF_VIEW
	far = 2000.0
	rotation = Vector3(-PITCH, 0.0, 0.0)
	_focus = _on_field(focus)
	_distance = FAR_DISTANCE if zoomed_out else NEAR_DISTANCE
	_apply()


## step < 0 zooms in, > 0 out.
func zoom(step: int) -> void:
	if step != 0:
		zoomed_out = step > 0


func follow(target: Vector2, delta: float) -> void:
	_focus = _focus.lerp(_on_field(target), 1.0 - exp(-FOLLOW_RATE * delta))
	var goal := FAR_DISTANCE if zoomed_out else NEAR_DISTANCE
	_distance = lerpf(_distance, goal, 1.0 - exp(-ZOOM_RATE * delta))
	_apply()


## Where the screen position hits the ground, or a non-finite vector if it misses.
static func field_point(camera: Camera3D, screen_position: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen_position)
	var normal := camera.project_ray_normal(screen_position)
	if normal.y > -0.0001:
		return Vector2(NAN, NAN)
	var hit := origin + normal * (-origin.y / normal.y)
	return Vector2(hit.x, hit.z)


func _on_field(point: Vector2) -> Vector3:
	return Vector3(clampf(point.x, 0.0, _field.x), 0.0, clampf(point.y, 0.0, _field.y))


func _apply() -> void:
	position = _focus + Vector3(0.0, sin(PITCH), cos(PITCH)) * _distance
