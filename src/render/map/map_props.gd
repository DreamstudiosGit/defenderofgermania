class_name MapProps
extends Node3D
## Small painted terrain pieces scattered over the fields (trees, peaks, hills, reeds, heather,
## houses), one multimesh per terrain, kept clear of the middle where the pieces stand.

const MAX_TRIES_PER_PROP := 30


## keep_clear: areas on the table per province (names) that props must not cover.
func build(map: MapData, board: MapBoard, keep_clear: Dictionary[String, Rect2]) -> void:
	var style := MapArt.section("props")
	var placed: Dictionary[String, Array] = {}
	for id: String in board.cells:
		var terrain := map.provinces[id].terrain
		var settings: Variant = style.get(terrain)
		if settings is Dictionary:
			if not placed.has(terrain):
				placed[terrain] = []
			var free_of := keep_clear.get(id, Rect2()) as Rect2
			placed[terrain].append_array(
				_scatter(id, board, settings as Dictionary, style, free_of)
			)
	for terrain: String in placed:
		_add_multimesh(terrain, placed[terrain], style[terrain] as Dictionary)


func _scatter(
	id: String, board: MapBoard, settings: Dictionary, style: Dictionary, free_of: Rect2
) -> Array:
	var cell := board.cells[id]
	var box := Rect2(cell[0], Vector2.ZERO)
	for point: Vector2 in cell:
		box = box.expand(point)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var scale := float(settings.get("scale", 1.0))
	var clump := int(settings.get("clump", 1))
	var count := roundi(MapGeometry.area(cell) / 100.0 * float(settings.get("per_100", 2.0)))
	var clear := float(style.get("keep_clear", 4.6))
	var gap := float(style.get("border_gap", 1.2)) * scale
	var result: Array = []
	var tries := 0
	while result.size() < count * clump and tries < count * MAX_TRIES_PER_PROP:
		tries += 1
		var anchor := Vector2(
			rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y)
		)
		for i: int in clump:
			var point := anchor + Vector2.from_angle(rng.randf() * TAU) * (0.9 * scale * i)
			if point.distance_to(board.centres[id]) < clear:
				continue
			if free_of.grow(0.6 * scale).has_point(point):
				continue
			if not Geometry2D.is_point_in_polygon(point, cell) or _edge_distance(point, cell) < gap:
				continue
			var size := scale * rng.randf_range(0.8, 1.2)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
			result.append(Transform3D(basis, Vector3(point.x, board.heights[id], point.y)))
	return result


func _add_multimesh(terrain: String, transforms: Array, settings: Dictionary) -> void:
	var mesh := MapPieceMeshes.prop(terrain)
	var colors: Array = settings.get("colors", [])
	for slot: int in mesh.get_surface_count():
		var paint := Color.from_string(str(colors[slot]) if slot < colors.size() else "", Color.GRAY)
		mesh.surface_set_material(slot, MapArt.paint(paint))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i] as Transform3D)
	var instance := MultiMeshInstance3D.new()
	instance.name = "Props_" + terrain
	instance.multimesh = multimesh
	add_child(instance)


static func _edge_distance(point: Vector2, polygon: PackedVector2Array) -> float:
	var nearest := INF
	for i: int in polygon.size():
		var on_edge := Geometry2D.get_closest_point_to_segment(
			point, polygon[i], polygon[(i + 1) % polygon.size()]
		)
		nearest = minf(nearest, point.distance_to(on_edge))
	return nearest
