class_name BattleCamera
extends Camera3D
## Orthographic camera tilted down by `camera.pitch_deg` (data/combat_art.json), not rotatable.
## Zoom level 0 frames every company on the field — at least the near width, at most the whole
## field — and follows the fight; level 1 stays at the near width around a focus point.

const ZOOM_LEVELS := 2
const DISTANCE := 200.0

var zoom_level: int = 0
var pitch: float = deg_to_rad(60.0)

var _field := Vector2.ZERO
var _center := Vector2.ZERO
var _points := PackedVector2Array()
var _focus := Vector2.ZERO


func setup(field_size: Vector2, focus: Vector2) -> void:
	_field = field_size
	pitch = deg_to_rad(float(_framing().get("pitch_deg", 60.0)))
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	far = 2000.0
	rotation = Vector3(-pitch, 0.0, 0.0)
	zoom_level = 0
	frame(PackedVector2Array(), focus, 0.0)
	if not get_viewport().size_changed.is_connected(_on_resize):
		get_viewport().size_changed.connect(_on_resize)


## Steps the zoom level: -1 out, +1 in.
func zoom(step: int) -> void:
	zoom_level = clampi(zoom_level + signi(step), 0, ZOOM_LEVELS - 1)


## points: companies to keep in view at level 0 (empty: the whole field); focus: the center
## at level 1. A delta of 0 jumps to the new view, otherwise the camera glides there.
func frame(points: PackedVector2Array, focus: Vector2, delta: float) -> void:
	_points = points
	_focus = focus
	var framing := _framing()
	var near := float(framing.get("near_width", 80.0))
	var rect := Rect2(focus - Vector2(near, 0.0) * 0.5, Vector2(near, 0.0))
	if zoom_level == 0:
		rect = _bounds(points, float(framing.get("company_margin", 20.0)))
		rect = rect.grow_individual(maxf(0.0, (near - rect.size.x) * 0.5), 0.0,
			maxf(0.0, (near - rect.size.x) * 0.5), 0.0)
	var target_size := minf(_view_height(rect.size), _view_height(_field))
	var target_center := rect.get_center().clamp(Vector2.ZERO, _field)
	var blend := 1.0
	if delta > 0.0:
		blend = 1.0 - exp(-float(framing.get("follow_speed", 2.5)) * delta)
	_center = _center.lerp(target_center, blend)
	size = lerpf(size, target_size, blend)
	var ground := Vector3(_center.x, 0.0, _center.y + float(framing.get("center_offset", 0.0)))
	position = ground + Vector3(0.0, sin(pitch), cos(pitch)) * DISTANCE


## Positions of the companies still on the field: what zoom level 0 keeps in view.
static func company_points(
	state: BattleState, positions: PackedVector2Array
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for c: int in mini(state.company_count(), positions.size()):
		if state.is_present(c):
			points.append(positions[c])
	return points


## Where zoom level 1 looks: the single human's active group; with two humans or none the
## melee (or every company), so the shared view never reveals a player's selection.
static func action_focus(
	state: BattleState, positions: PackedVector2Array, selection: Array[bool], fallback: Vector2
) -> Vector2:
	var picked := PackedVector2Array()
	var melee := PackedVector2Array()
	for c: int in mini(state.company_count(), positions.size()):
		if state.status[c] != BattleState.Status.ACTIVE:
			continue
		var s := state.side[c]
		if selection[s] and state.group[c] == state.active_group[s]:
			picked.append(positions[c])
		if state.contact[c] >= 0:
			melee.append(positions[c])
	if picked.is_empty():
		picked = melee
	if picked.is_empty():
		picked = company_points(state, positions)
	var sum := Vector2.ZERO
	for point: Vector2 in picked:
		sum += point
	return sum / picked.size() if not picked.is_empty() else fallback


## Where the screen position hits the ground, or a non-finite vector if it misses.
static func field_point(camera: Camera3D, screen_position: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen_position)
	var normal := camera.project_ray_normal(screen_position)
	if normal.y > -0.0001:
		return Vector2(NAN, NAN)
	var hit := origin + normal * (-origin.y / normal.y)
	return Vector2(hit.x, hit.z)


## Height of the orthographic view that shows a ground area of this size with margins.
func _view_height(area: Vector2) -> float:
	var framing := _framing()
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var margin := float(framing.get("horizontal_margin", 12.0))
	var height := area.y * sin(pitch) + float(framing.get("vertical_margin", 19.0))
	return maxf(height, (area.x + margin) / aspect)


func _bounds(points: PackedVector2Array, margin: float) -> Rect2:
	if points.is_empty():
		return Rect2(Vector2.ZERO, _field)
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect.grow(margin).intersection(Rect2(Vector2.ZERO, _field))


func _on_resize() -> void:
	frame(_points, _focus, 0.0)


static func _framing() -> Dictionary:
	return BattleModels.settings().get("camera", {})
