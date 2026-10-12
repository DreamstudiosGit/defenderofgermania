class_name SiegeRing
extends Node3D
## The castle's enclosure around the cross-section the trebuchet shoots along: wall or
## palisade segments stretched to fit the front line (beside the gate), the back line (beside
## the rear segment the rules know) and both sides, with towers on the corners ("rings" and
## each layout's "ring" in data/combat_siege_art.json). Scenery only.

const SEGMENT_LENGTH := 10.0
const TOWER_HEIGHT := 10.5
## Half the length of the rear segment that stands in the line of fire as a layout part.
const REAR_GAP := 5.0


func build(ring: Dictionary, front: float, colors: PackedColorArray) -> void:
	clear()
	if ring.is_empty():
		return
	var style: Dictionary = SiegeArt.section("rings").get(str(ring.get("style", "")), {})
	var piece := str(style.get("segment", ""))
	var scale := SiegeArt.scale_of(style.get("scale", 1.0))
	var x_front := front + float(ring.get("front", 0.0))
	var x_back := front + float(ring.get("back", 0.0))
	var half := float(ring.get("half_width", 20.0))
	var gate := float(ring.get("gate_half", 3.0))
	for side: float in [-1.0, 1.0]:
		_line(piece, scale, Vector3(x_front, 0, gate * side), Vector3(x_front, 0, half * side), -90)
		_line(piece, scale, Vector3(x_back, 0, REAR_GAP * side), Vector3(x_back, 0, half * side),
			-90)
		_line(piece, scale, Vector3(x_front, 0, half * side), Vector3(x_back, 0, half * side),
			0.0 if side > 0.0 else 180.0)
	var tower := str(style.get("tower", ""))
	if tower.is_empty():
		return
	var tower_scale := float(style.get("tower_scale", 1.0))
	var roof := str(ring.get("roofs", ""))
	for x: float in [x_front, x_back]:
		for side: float in [-1.0, 1.0]:
			var at := Vector3(x, 0.0, half * side)
			_place(tower, at, 0.0, Vector3.ONE * tower_scale, colors)
			if not roof.is_empty():
				_place(roof, at + Vector3.UP * TOWER_HEIGHT * tower_scale, 0.0,
					Vector3.ONE * tower_scale, colors)


func clear() -> void:
	for child: Node in get_children():
		child.queue_free()


## Segments from a to b, as many as needed and stretched along their length to fit.
func _line(piece: String, scale: Vector3, a: Vector3, b: Vector3, yaw: float) -> void:
	var length := a.distance_to(b)
	if length < 0.5 or piece.is_empty():
		return
	var count := ceili(length / (SEGMENT_LENGTH * scale.x))
	var stretch := length / (count * SEGMENT_LENGTH)
	for k: int in count:
		var at := a.lerp(b, (k + 0.5) / count)
		_place(piece, at, yaw, Vector3(stretch, scale.y, scale.z), PackedColorArray())


func _place(
	piece: String, at: Vector3, yaw: float, scale: Vector3, colors: PackedColorArray
) -> void:
	var node := SiegeArt.instance(piece, yaw, scale)
	node.position = at
	if SiegeArt.has_house_colors(piece) and colors.size() >= 2:
		node.set_instance_shader_parameter("house_primary", colors[0])
		node.set_instance_shader_parameter("house_secondary", colors[1])
	add_child(node)
