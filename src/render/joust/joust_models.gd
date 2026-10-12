class_name JoustModels
extends RefCounted
## Meshes of the joust: the battle's knight split into horse and rider (so a rider can fall from
## the saddle) without the knight's upright lance, and a striped jousting lance in two parts
## (the front part breaks off).

const RIDER_UNIT := "knights"
## The knight holds his lance upright; every triangle reaching above this belongs to it.
const LANCE_CUT_Y := 3.35
const LANCE_LENGTH := 4.0
## The grip sits this far from the butt; the lance breaks this far from the butt.
const GRIP := 0.9
const BREAK := 1.5
const SIDES := 8
const IRON := Color(0.54, 0.56, 0.59)
const LANCE_SHADER := preload("res://src/render/joust/joust_lance.gdshader")

static var _riders: Dictionary[String, Array] = {}
static var _lance: Array[ArrayMesh] = []


## [horse, rider] of a knight with the owner's crest; house colours come from the batch's
## house_primary / house_secondary instance uniforms like the battle figures.
static func rider_meshes(owner: String) -> Array[ArrayMesh]:
	if _riders.has(owner):
		return _riders[owner]
	var parts: Array[ArrayMesh] = []
	var source := BattleModels.unit_mesh(RIDER_UNIT, owner)
	if source == null:
		return parts
	var horse := ArrayMesh.new()
	var rider := ArrayMesh.new()
	var horse_surfaces := _horse_surface_count()
	for surface: int in source.get_surface_count():
		_copy_below_cut(source, surface, horse if surface < horse_surfaces else rider)
	parts.assign([horse, rider])
	_riders[owner] = parts
	return parts


## [rear, front] of the lance along +y from the butt; the front breaks off on a perfect hit.
static func lance_meshes() -> Array[ArrayMesh]:
	if not _lance.is_empty():
		return _lance
	var paint := ShaderMaterial.new()
	paint.shader = LANCE_SHADER
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	iron.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var rear := ArrayMesh.new()
	_add_surface(rear, paint, [[0.0, BREAK, 0.075, 0.062]])
	_add_surface(rear, iron, [[GRIP + 0.05, GRIP + 0.4, 0.2, 0.07], [GRIP, GRIP + 0.05, 0.2, 0.2]])
	var front := ArrayMesh.new()
	_add_surface(front, paint, [[BREAK, LANCE_LENGTH - 0.12, 0.062, 0.036]])
	_add_surface(front, iron, [[LANCE_LENGTH - 0.12, LANCE_LENGTH, 0.06, 0.05]])
	_lance.assign([rear, front])
	return _lance


## Surface count of the knight's horse, which BattleModels merges before the rider.
static func _horse_surface_count() -> int:
	var units: Dictionary = BattleModels.settings().get("unit_models", {})
	var path := BattleModels.DIRECTORY + "unit_%s.glb" % units.get(RIDER_UNIT, "knight")
	var scene := load(path) as PackedScene
	if scene == null:
		return 0
	var root := scene.instantiate()
	var count := 0
	for node: Node in root.find_children("*_horse", "MeshInstance3D"):
		count += (node as MeshInstance3D).mesh.get_surface_count()
	root.free()
	return count


static func _copy_below_cut(source: ArrayMesh, surface: int, target: ArrayMesh) -> void:
	var arrays := source.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	var original: Variant = arrays[Mesh.ARRAY_INDEX]
	if original is PackedInt32Array and not (original as PackedInt32Array).is_empty():
		indices = original
	else:
		for i: int in vertices.size():
			indices.append(i)
	var kept := PackedInt32Array()
	for t: int in range(0, indices.size() - 2, 3):
		var low := maxf(vertices[indices[t]].y, vertices[indices[t + 1]].y)
		var top := maxf(low, vertices[indices[t + 2]].y)
		if top <= LANCE_CUT_Y:
			kept.append_array([indices[t], indices[t + 1], indices[t + 2]])
	if kept.is_empty():
		return
	arrays[Mesh.ARRAY_INDEX] = kept
	target.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
	target.surface_set_material(target.get_surface_count() - 1, source.surface_get_material(surface))


## Adds tapered rings [y0, y1, r0, r1] around +y with UVs running round (x) and along (y).
static func _add_surface(mesh: ArrayMesh, material: Material, rings: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: Array in rings:
		var y0: float = ring[0]
		var y1: float = ring[1]
		var r0: float = ring[2]
		var r1: float = ring[3]
		for side: int in SIDES:
			var a0 := TAU * side / SIDES
			var a1 := TAU * (side + 1) / SIDES
			var corners: Array[Vector3] = [
				Vector3(cos(a0) * r0, y0, sin(a0) * r0), Vector3(cos(a1) * r0, y0, sin(a1) * r0),
				Vector3(cos(a1) * r1, y1, sin(a1) * r1), Vector3(cos(a0) * r1, y1, sin(a0) * r1),
			]
			var uvs: Array[Vector2] = [
				Vector2(float(side) / SIDES, y0 / LANCE_LENGTH),
				Vector2(float(side + 1) / SIDES, y0 / LANCE_LENGTH),
				Vector2(float(side + 1) / SIDES, y1 / LANCE_LENGTH),
				Vector2(float(side) / SIDES, y1 / LANCE_LENGTH),
			]
			for corner: int in [0, 2, 1, 0, 3, 2]:
				st.set_uv(uvs[corner])
				st.add_vertex(corners[corner])
		for cap: Array in [[y0, r0, false], [y1, r1, true]]:
			for side: int in SIDES:
				var a0 := TAU * side / SIDES
				var a1 := TAU * (side + 1) / SIDES
				var y: float = cap[0]
				var r: float = cap[1]
				var points: Array[Vector3] = [
					Vector3(0, y, 0), Vector3(cos(a0) * r, y, sin(a0) * r),
					Vector3(cos(a1) * r, y, sin(a1) * r),
				]
				var order := PackedInt32Array([0, 1, 2] if cap[2] else [0, 2, 1])
				for corner: int in order:
					st.set_uv(Vector2(0.0, y / LANCE_LENGTH))
					st.add_vertex(points[corner])
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
