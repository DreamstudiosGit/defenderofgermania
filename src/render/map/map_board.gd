class_name MapBoard
extends Node3D
## The realm on the map table: one raised field per province, painted in its owner's colour,
## with ink borders, a painted name and a glowing rim for selection and reachable provinces.

const FIELD_SHADER := preload("res://src/render/map/map_field.gdshader")
const INK_LIFT := 0.006
const RIM_LIFT := 0.012

## Province cells in table units (x east, y = world z south), wobbled like the drawn borders.
var cells: Dictionary[String, PackedVector2Array] = {}
var centres: Dictionary[String, Vector2] = {}
## Height of each field's top above the table.
var heights: Dictionary[String, float] = {}
## The realm's coast and land border in table units.
var realm := PackedVector2Array()
var bounds := Rect2()
var sheet_top: float = 0.12

var _origin_km := Vector2.ZERO
var _fields: Dictionary[String, MeshInstance3D] = {}
var _select_rims: Dictionary[String, MeshInstance3D] = {}
var _highlight_rims: Dictionary[String, MeshInstance3D] = {}
var _paper := Color.WHITE


func build(map: MapData) -> void:
	sheet_top = MapArt.number("sheet", "height", 0.12)
	_paper = MapArt.color("sheet", "paper", Color(0.84, 0.75, 0.58))
	var outline_km := map.geography.outline_km()
	var box := Rect2(outline_km[0], Vector2.ZERO)
	for point: Vector2 in outline_km:
		box = box.expand(point)
	_origin_km = box.get_center()
	var amplitude := MapArt.number("border", "wobble_amplitude_km", 5.0)
	var wavelength := MapArt.number("border", "wobble_wavelength_km", 95.0)
	var step := MapArt.number("border", "wobble_step_km", 5.0)
	var raw := MapGeometry.province_cells(map)
	var wobbled := MapGeometry.wobbled_cells(raw, amplitude, wavelength, step)
	var centres_km := MapGeometry.centres_km(map)
	for id: String in wobbled:
		cells[id] = to_table_polygon(wobbled[id])
		centres[id] = to_table(centres_km[id])
	realm = to_table_polygon(MapGeometry.wobble(outline_km, amplitude, wavelength, step))
	bounds = Rect2(realm[0], Vector2.ZERO)
	for point: Vector2 in realm:
		bounds = bounds.expand(point)
	var terrain_heights: Dictionary = MapArt.section("field").get("terrain_heights", {})
	var base := MapArt.number("field", "base_height", 0.5)
	for id: String in cells:
		var terrain := map.provinces[id].terrain
		heights[id] = sheet_top + base + float(terrain_heights.get(terrain, 0.0))
	_build_fields()
	_build_ink()


func to_table(km: Vector2) -> Vector2:
	return (km - _origin_km) / MapArt.km_per_unit()


func to_table_polygon(km_points: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in km_points:
		points.append(to_table(point))
	return points


## The province whose field covers the table point (x, z), or "".
func province_at_point(point: Vector2) -> String:
	return MapGeometry.cell_at(cells, point)


func world_position(province_id: String) -> Vector3:
	if not centres.has(province_id):
		return Vector3.ZERO
	var centre := centres[province_id]
	return Vector3(centre.x, heights[province_id], centre.y)


## A point on the field `distance` from its centre towards `direction`, kept well inside it.
func spot(province_id: String, direction: Vector2, distance: float) -> Vector3:
	var centre := centres[province_id]
	var unit := direction.normalized()
	var room := distance / 0.6
	var polygon := cells[province_id]
	for i: int in polygon.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(
			centre, centre + unit * room, polygon[i], polygon[(i + 1) % polygon.size()]
		)
		if hit is Vector2:
			room = minf(room, centre.distance_to(hit as Vector2))
	var point := centre + unit * minf(distance, room * 0.6)
	return Vector3(point.x, heights[province_id], point.y)


func paint(map: MapData, state: GameState) -> void:
	var mix := MapArt.number("field", "paint_mix", 0.12)
	for id: String in _fields:
		var owner := state.provinces[id].owner if state.provinces.has(id) else ""
		var color := MapArt.owner_color(map, owner).lerp(_paper, mix)
		_fields[id].set_instance_shader_parameter("paint", color)


## Gold rim and glow on the selected province, a softer one on the highlighted ones.
func set_selection(province_id: String, highlights: Array[String]) -> void:
	var selected := MapArt.number("field", "glow_selected", 0.3)
	var soft := MapArt.number("field", "glow_highlight", 0.12)
	for id: String in _fields:
		var is_selected := id == province_id
		var is_highlighted := not is_selected and id in highlights
		_select_rims[id].visible = is_selected
		_highlight_rims[id].visible = is_highlighted
		var glow := selected if is_selected else (soft if is_highlighted else 0.0)
		_fields[id].set_instance_shader_parameter("glow", glow)


func field_count() -> int:
	return _fields.size()


func _build_fields() -> void:
	var material := ShaderMaterial.new()
	material.shader = FIELD_SHADER
	material.set_shader_parameter("variation", MapArt.number("field", "variation", 0.1))
	for id: String in cells:
		var field := MeshInstance3D.new()
		field.name = "Field_" + id
		field.mesh = MapMeshes.prism(cells[id], sheet_top, heights[id])
		field.material_override = material
		add_child(field)
		_fields[id] = field


func _build_ink() -> void:
	var ink := MapArt.color("ink", "color", Color.BLACK)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := MapArt.number("border", "ink_width", 0.16)
	for id: String in cells:
		MapMeshes.add_inner_ribbon(tool, cells[id], width, heights[id] + INK_LIFT)
	var coast := MapArt.number("border", "coast_width", 0.34)
	var outward := -signf(MapGeometry.signed_area(realm))
	MapMeshes.add_ribbon(tool, realm, true, coast, sheet_top + INK_LIFT, coast * 0.5 * outward)
	var lines := MeshInstance3D.new()
	lines.name = "Borders"
	lines.mesh = tool.commit()
	lines.material_override = MapArt.flat(ink)
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines)
	var select := MapArt.flat(MapArt.color("field", "select_color", Color.GOLD))
	var highlight := MapArt.flat(MapArt.color("field", "highlight_color", Color.WHITE))
	for id: String in cells:
		var select_width := MapArt.number("field", "select_width", 0.38)
		var highlight_width := MapArt.number("field", "highlight_width", 0.2)
		_select_rims[id] = _rim("SelectRim_" + id, cells[id], heights[id], select_width, select)
		_highlight_rims[id] = _rim(
			"HighlightRim_" + id, cells[id], heights[id], highlight_width, highlight
		)


func _rim(
	node_name: String, cell: PackedVector2Array, height: float, width: float,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	MapMeshes.add_inner_ribbon(tool, cell, width, height + RIM_LIFT)
	var rim := MeshInstance3D.new()
	rim.name = node_name
	rim.mesh = tool.commit()
	rim.material_override = material
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rim.visible = false
	add_child(rim)
	return rim
