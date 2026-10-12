class_name RaidMarkers
extends Control
## Readable fight cues drawn over the raid: for the guard the leader faces, its health and the
## height it covers (a shield mark) and, while it winds up, a red warning at the height of the
## coming blow; for the leader, the height his next blow or parry will take.

## Body heights of the three blow heights above the feet.
const HEIGHTS: Array[float] = [1.65, 1.15, 0.55]
const SHIELD_SIZE := 11.0
const BAR_SIZE := Vector2(70, 8)
const WARNING := Color(0.95, 0.22, 0.12)

var _guard_points: Array[Vector2] = []
var _guard_head := Vector2.ZERO
var _guard_health: float = -1.0
var _stance: int = -1
var _warning: int = -1
var _warning_strength: float = 0.0
var _leader_points: Array[Vector2] = []
var _selected: int = -1
var _guard_color := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func update_view(
	sim: RaidSim, figures: RaidFigures, camera: Camera3D, selected: int, guard_color: Color
) -> void:
	var state := sim.state
	_guard_color = guard_color
	_guard_health = -1.0
	_stance = -1
	_warning = -1
	_selected = selected if not state.is_sneaking() and not state.over else -1
	_leader_points = _points(camera, figures.leader.global_position, 0.55)
	if state.engaged and state.front >= 0 and state.front < figures.guards.size():
		var guard := state.guards[state.front]
		var figure := figures.guards[state.front]
		_guard_points = _points(camera, figure.global_position, -0.6)
		_guard_head = camera.unproject_position(figure.global_position + Vector3.UP * 2.25)
		_guard_health = guard.health / maxf(guard.max_health, 1.0)
		if guard.action == RaidFighter.Action.READY:
			_stance = guard.stance
		if guard.action == RaidFighter.Action.WINDUP:
			_warning = guard.height
			_warning_strength = clampf(guard.progress(), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _guard_health >= 0.0:
		var corner := _guard_head - BAR_SIZE * 0.5
		draw_rect(
			Rect2(corner - Vector2(2, 2), BAR_SIZE + Vector2(4, 4)), Color(0.08, 0.05, 0.03, 0.85)
		)
		draw_rect(Rect2(corner, Vector2(BAR_SIZE.x * _guard_health, BAR_SIZE.y)), _guard_color)
		for h: int in 3:
			var covered := h == _stance
			_shield(_guard_points[h], covered, _guard_color)
	if _warning >= 0:
		var at := _guard_points[_warning]
		var size := 10.0 + 8.0 * _warning_strength
		var points := PackedVector2Array([
			at + Vector2(size, -size), at + Vector2(-size * 0.4, 0), at + Vector2(size, size)
		])
		draw_colored_polygon(points, Color(WARNING, 0.55 + 0.45 * _warning_strength))
		draw_polyline(points + PackedVector2Array([points[0]]), Color(0.1, 0.05, 0.03), 2.0)
	if _selected >= 0 and _leader_points.size() == 3:
		var at := _leader_points[_selected]
		var points := PackedVector2Array([
			at + Vector2(-9, -8), at + Vector2(7, 0), at + Vector2(-9, 8)
		])
		draw_colored_polygon(points, GroupShield.GOLD)
		draw_polyline(points + PackedVector2Array([points[0]]), Color(0.1, 0.05, 0.03), 2.0)


func _points(camera: Camera3D, feet: Vector3, side: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for height: float in HEIGHTS:
		points.append(camera.unproject_position(feet + Vector3(side, height, 0.8)))
	return points


func _shield(at: Vector2, filled: bool, color: Color) -> void:
	var s := SHIELD_SIZE
	var points := PackedVector2Array([
		at + Vector2(-s, -s), at + Vector2(s, -s), at + Vector2(s, s * 0.2),
		at + Vector2(0, s * 1.2), at + Vector2(-s, s * 0.2)
	])
	if filled:
		draw_colored_polygon(points, color)
	draw_polyline(
		points + PackedVector2Array([points[0]]),
		Color(0.1, 0.05, 0.03, 0.9 if filled else 0.4),
		2.0
	)
