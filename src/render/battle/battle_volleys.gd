class_name BattleVolleys
extends MeshInstance3D
## Short-lived bolt streaks for crossbow volleys and trebuchet stones in flight, redrawn every
## frame with an ImmediateMesh.

const FLIGHT_SECONDS := 0.6
const BOLTS := 7
const SPREAD := 3.0
const ARC_HEIGHT := 7.0
const STREAK := 0.12
const BOLT_COLOR := Color(0.15, 0.12, 0.1)
const STONE_ARC := 40.0
const STONE_SIZE := 0.8

var _from := PackedVector2Array()
var _to := PackedVector2Array()
var _age := PackedFloat64Array()
var _stone_from := PackedVector2Array()
var _stone_to := PackedVector2Array()
var _stone_age := PackedFloat64Array()
var _stone_time := PackedFloat64Array()
var _lines := ImmediateMesh.new()


func _ready() -> void:
	mesh = _lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func launch(from: Vector2, to: Vector2) -> void:
	_from.append(from)
	_to.append(to)
	_age.append(0.0)


## A trebuchet stone that lands on `to` after `seconds`, like the simulation's shot.
func launch_stone(from: Vector2, to: Vector2, seconds: float) -> void:
	_stone_from.append(from)
	_stone_to.append(to)
	_stone_age.append(0.0)
	_stone_time.append(maxf(seconds, 0.01))


func clear() -> void:
	_from.clear()
	_to.clear()
	_age.clear()
	_stone_from.clear()
	_stone_to.clear()
	_stone_age.clear()
	_stone_time.clear()
	_lines.clear_surfaces()


func _process(delta: float) -> void:
	_lines.clear_surfaces()
	for i: int in range(_age.size() - 1, -1, -1):
		_age[i] += delta
		if _age[i] > FLIGHT_SECONDS:
			_from.remove_at(i)
			_to.remove_at(i)
			_age.remove_at(i)
	for i: int in range(_stone_age.size() - 1, -1, -1):
		_stone_age[i] += delta
		if _stone_age[i] > _stone_time[i]:
			_stone_from.remove_at(i)
			_stone_to.remove_at(i)
			_stone_age.remove_at(i)
			_stone_time.remove_at(i)
	if _age.is_empty() and _stone_age.is_empty():
		return
	_lines.surface_begin(Mesh.PRIMITIVE_LINES)
	_lines.surface_set_color(BOLT_COLOR)
	for i: int in _age.size():
		var t := _age[i] / FLIGHT_SECONDS
		for bolt: int in BOLTS:
			var offset := Vector2.from_angle(bolt * 2.4) * SPREAD * (bolt % 3 + 1) / 3.0
			_lines.surface_add_vertex(_point(_from[i], _to[i] + offset, maxf(0.0, t - STREAK)))
			_lines.surface_add_vertex(_point(_from[i], _to[i] + offset, t))
	for i: int in _stone_age.size():
		var at := _point(_stone_from[i], _stone_to[i], _stone_age[i] / _stone_time[i], STONE_ARC)
		for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			_lines.surface_add_vertex(at - axis * STONE_SIZE)
			_lines.surface_add_vertex(at + axis * STONE_SIZE)
	_lines.surface_end()


func _point(from: Vector2, to: Vector2, t: float, arc: float = ARC_HEIGHT) -> Vector3:
	var ground := from.lerp(to, t)
	return Vector3(ground.x, 1.5 + sin(t * PI) * arc, ground.y)
