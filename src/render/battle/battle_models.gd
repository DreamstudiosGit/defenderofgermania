class_name BattleModels
extends RefCounted

const DIRECTORY := "res://assets/combat/"
const MOTION := preload("res://src/render/battle/unit_motion.gdshader")
const WIND := preload("res://src/render/battle/foliage_wind.gdshader")
const WATER := preload("res://src/render/battle/river_water.gdshader")
const PATH := preload("res://src/render/battle/path_surface.gdshader")

static var _meshes: Dictionary[String, ArrayMesh] = {}
static var _art: Dictionary = {}


static func settings() -> Dictionary:
	if _art.is_empty():
		var data: Variant = DataReader.load_json("res://data/combat_art.json")
		if data is Dictionary:
			_art = data
		else:
			push_error("combat art: expected a settings object")
	return _art


static func unit_mesh(unit_id: String, side: int) -> ArrayMesh:
	var art := settings()
	var units: Dictionary = art.get("unit_models", {})
	var teams: Array = art.get("teams", [])
	if not units.has(unit_id) or side < 0 or side >= teams.size():
		push_error("combat art: no model for unit %s, side %d" % [unit_id, side])
		return null
	return mesh("unit_%s_%s" % [units[unit_id], teams[side]], true)


static func mesh(filename: String, animated: bool = false) -> ArrayMesh:
	var cache_key := filename + ("_animated" if animated else "")
	if _meshes.has(cache_key):
		return _meshes[cache_key]
	var path := DIRECTORY + filename + ".glb"
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("combat art: cannot load %s" % path)
		return null
	var root := scene.instantiate()
	var result := ArrayMesh.new()
	_collect(root, Transform3D.IDENTITY, result, animated, filename)
	root.free()
	if result.get_surface_count() == 0:
		push_error("combat art: no mesh surfaces in %s" % path)
		return null
	_meshes[cache_key] = result
	return result


static func _collect(
	node: Node, parent: Transform3D, result: ArrayMesh, animated: bool, filename: String
) -> void:
	var transform := parent
	if node is Node3D:
		transform *= (node as Node3D).transform
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		# Spears are a separate batch so hedgehogs can tilt them towards their own slot.
		if instance.mesh != null and not (animated and instance.name == "weapon_spear"):
			for surface: int in instance.mesh.get_surface_count():
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				builder.append_from(instance.mesh, surface, transform)
				builder.commit(result)
				var material := instance.get_active_material(surface)
				if animated:
					material = _shader_material(material, MOTION, "animation")
				elif material != null and material.resource_name == "water":
					material = _shader_material(material, WATER, "water")
				elif filename == "terrain_path":
					material = _shader_material(material, PATH, "path")
				elif filename.begins_with("tree_") or (
					filename.begins_with("foliage_") and filename != "foliage_stump"
				):
					material = _shader_material(material, WIND, "wind")
				result.surface_set_material(result.get_surface_count() - 1, material)
	for child: Node in node.get_children():
		_collect(child, transform, result, animated, filename)


static func _shader_material(source: Material, shader: Shader, section: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	if source is StandardMaterial3D:
		var standard := source as StandardMaterial3D
		material.set_shader_parameter("albedo", standard.albedo_color)
		material.set_shader_parameter("metallic", standard.metallic)
		material.set_shader_parameter("roughness", standard.roughness)
	var art := settings()
	var parameters: Dictionary = art.get(section, {})
	for key: String in parameters:
		var value: Variant = parameters[key]
		if value is String and key.ends_with("_color"):
			value = Color.from_string(value, Color.WHITE)
		material.set_shader_parameter(key, value)
	return material
