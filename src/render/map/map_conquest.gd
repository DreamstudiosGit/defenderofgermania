class_name MapConquest
extends Node3D
## The accent for a province that changed hands: its field blends from the old owner's paint
## to the new one while a bright rim swells out of its border and fades ("motion" in
## data/map_art.json). The board starts an accent and has the final colour in its books at
## once; this node only lets the picture catch up, and rests when nothing runs.

const PAINT := &"paint"
const STRENGTH := &"strength"
const RIM_LIFT := 0.02

var _running: Array[Accent] = []
## Rims of finished accents, kept for the next ones.
var _spare_rims: Array[MeshInstance3D] = []
var _material: ShaderMaterial
var _paint_seconds: float = 0.4
var _rim_seconds: float = 0.6
var _growth: float = 0.07


class Accent:
	var province := ""
	var field: MeshInstance3D
	var rim: MeshInstance3D
	var from := Color.WHITE
	var to := Color.WHITE
	## The province's centre on the table; the rim swells away from it.
	var centre := Vector3.ZERO
	var time := 0.0


func _init() -> void:
	var motion := MapArt.section("motion")
	_paint_seconds = float(motion.get("paint_seconds", 0.4))
	_rim_seconds = float(motion.get("conquest_seconds", 0.6))
	_growth = float(motion.get("conquest_growth", 0.07))
	_material = MapArt.rim(MapArt.color("motion", "conquest_color", Color.WHITE))


func _ready() -> void:
	set_process(not _running.is_empty())


## Blends the field from the colour it shows to `color`; `outline` is the province's border
## as a rim mesh in table coordinates.
func start(
	province: String, field: MeshInstance3D, color: Color, outline: Mesh, centre: Vector3
) -> void:
	var accent := _accent_of(province)
	if accent == null:
		accent = Accent.new()
		accent.province = province
		accent.field = field
		accent.rim = _new_rim() if _spare_rims.is_empty() else _spare_rims.pop_back()
		_running.append(accent)
	accent.from = field.get_instance_shader_parameter(PAINT)
	accent.to = color
	accent.centre = centre
	accent.time = 0.0
	accent.rim.mesh = outline
	accent.rim.visible = true
	_show(accent)
	set_process(true)


## Ends the province's accent at once, the field in its final colour.
func settle(province: String) -> void:
	var accent := _accent_of(province)
	if accent != null:
		accent.field.set_instance_shader_parameter(PAINT, accent.to)
		_retire(accent)


func is_running(province: String) -> bool:
	return _accent_of(province) != null


func _process(delta: float) -> void:
	advance(delta)


## Moves every accent on by `delta` seconds.
func advance(delta: float) -> void:
	for index: int in range(_running.size() - 1, -1, -1):
		var accent := _running[index]
		accent.time += delta
		_show(accent)
		if accent.time >= maxf(_paint_seconds, _rim_seconds):
			_retire(accent)
	if _running.is_empty():
		set_process(false)


func _show(accent: Accent) -> void:
	var blend := clampf(accent.time / maxf(_paint_seconds, 0.001), 0.0, 1.0)
	var eased := blend * blend * (3.0 - 2.0 * blend)
	var color := accent.to if blend >= 1.0 else accent.from.lerp(accent.to, eased)
	accent.field.set_instance_shader_parameter(PAINT, color)
	var pulse := clampf(accent.time / maxf(_rim_seconds, 0.001), 0.0, 1.0)
	var size := 1.0 + _growth * (1.0 - (1.0 - pulse) * (1.0 - pulse))
	# Scaled about the province's centre, not the table's.
	accent.rim.scale = Vector3(size, 1.0, size)
	accent.rim.position = Vector3(
		accent.centre.x * (1.0 - size), RIM_LIFT, accent.centre.z * (1.0 - size)
	)
	accent.rim.set_instance_shader_parameter(STRENGTH, 1.0 - pulse)


func _retire(accent: Accent) -> void:
	accent.rim.visible = false
	_spare_rims.append(accent.rim)
	_running.erase(accent)


func _accent_of(province: String) -> Accent:
	for accent: Accent in _running:
		if accent.province == province:
			return accent
	return null


func _new_rim() -> MeshInstance3D:
	var rim := MeshInstance3D.new()
	rim.name = "ConquestRim"
	rim.material_override = _material
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	return rim
