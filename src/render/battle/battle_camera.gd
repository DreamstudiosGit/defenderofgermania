class_name BattleCamera
extends Camera3D
## Fixed orthographic composition; the entire battlefield stays visible during play.

const PITCH := 0.6981317008

var _field := Vector2.ZERO


func setup(field_size: Vector2, _focus: Vector2) -> void:
	_field = field_size
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	far = 2000.0
	rotation = Vector3(-PITCH, 0.0, 0.0)
	_compose()
	if not get_viewport().size_changed.is_connected(_compose):
		get_viewport().size_changed.connect(_compose)


## Where the screen position hits the ground, or a non-finite vector if it misses.
static func field_point(camera: Camera3D, screen_position: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen_position)
	var normal := camera.project_ray_normal(screen_position)
	if normal.y > -0.0001:
		return Vector2(NAN, NAN)
	var hit := origin + normal * (-origin.y / normal.y)
	return Vector2(hit.x, hit.z)


func _compose() -> void:
	var art := BattleModels.settings()
	var framing: Dictionary = art.get("camera", {})
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var margin := float(framing.get("horizontal_margin", 12.0))
	var height := _field.y * sin(PITCH) + float(framing.get("vertical_margin", 19.0))
	size = maxf(height, (_field.x + margin) / aspect)
	var center := Vector3(_field.x * 0.5, 0, _field.y * 0.5)
	center.z += float(framing.get("center_offset", 0.0))
	position = center + Vector3(0.0, sin(PITCH), cos(PITCH)) * 100.0
