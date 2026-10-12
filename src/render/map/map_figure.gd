class_name MapFigure
extends Node3D
## One army on the map table: a painted wooden knight in its owner's colours, its company
## count, and a gold ring with the figure lifted while it is selected.

const HEIGHT := 1.3
const RADIUS := 0.4
const COUNT_AT := Vector3(0.38, 1.38, 0.0)

var _body := MeshInstance3D.new()
var _count := Label3D.new()
var _ring := MeshInstance3D.new()
var _scale: float = 2.7
var _lift: float = 0.8


func _init() -> void:
	var pieces := MapArt.section("pieces")
	_scale = float(pieces.get("figure_scale", 2.7))
	_lift = float(pieces.get("lift", 0.8))
	_body.mesh = MapPieceMeshes.figure()
	_body.scale = Vector3.ONE * _scale
	add_child(_body)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.4 * _scale
	ring.outer_radius = 0.5 * _scale
	ring.rings = 32
	_ring.mesh = ring
	_ring.position.y = 0.05
	_ring.material_override = MapArt.flat(MapArt.color("pieces", "ring_color", Color.GOLD))
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_count.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_count.fixed_size = true
	_count.no_depth_test = true
	_count.render_priority = 2
	_count.outline_render_priority = 1
	_count.font_size = int(pieces.get("count_font_size", 40))
	_count.pixel_size = float(pieces.get("count_pixel_size", 0.0006))
	_count.outline_size = 12
	_count.modulate = MapArt.color("pieces", "count_color", Color.WHITE)
	_count.outline_modulate = MapArt.color("pieces", "count_outline_color", Color.BLACK)
	_count.position = COUNT_AT * _scale
	add_child(_count)


func show_army(companies: int, paints: Array[Color]) -> void:
	_count.text = str(companies)
	for slot: int in mini(_body.mesh.get_surface_count(), paints.size()):
		_body.set_surface_override_material(slot, MapArt.paint(paints[slot]))


func set_selected(selected: bool) -> void:
	_ring.visible = selected
	_body.position.y = _lift if selected else 0.0
	_count.position.y = COUNT_AT.y * _scale + (_lift if selected else 0.0)


func foot() -> Vector3:
	return global_position + _body.position


func head() -> Vector3:
	return foot() + Vector3.UP * HEIGHT * _scale


func radius() -> float:
	return RADIUS * _scale
