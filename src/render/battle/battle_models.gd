class_name BattleModels
extends RefCounted

const DIRECTORY := "res://assets/combat/"
const MOTION := preload("res://src/render/battle/unit_motion.gdshader")
const OUTLINE := preload("res://src/render/battle/unit_outline.gdshader")
## Blender material names whose surfaces take the house colours (unit_motion house_slot).
const HOUSE_SLOTS: Dictionary[String, int] = {"house_primary": 1, "house_secondary": 2}
const WIND := preload("res://src/render/battle/foliage_wind.gdshader")
const WATER := preload("res://src/render/battle/river_water.gdshader")
const PATH := preload("res://src/render/battle/path_surface.gdshader")

static var _meshes: Dictionary[String, ArrayMesh] = {}
static var _art: Dictionary = {}
static var _outline: ShaderMaterial
## Rest-pose transform of each export's `crest_anchor` node, by export name.
static var _anchors: Dictionary[String, Transform3D] = {}


static func settings() -> Dictionary:
	if _art.is_empty():
		var data: Variant = DataReader.load_json("res://data/combat_art.json")
		if data is Dictionary:
			_art = data
		else:
			push_error("combat art: expected a settings object")
	return _art


## The house-neutral model of a unit with the house's crest on its helmet, if it wears one.
## House colours come from the batch's house_primary / house_secondary instance uniforms.
static func unit_mesh(unit_id: String, house: String) -> ArrayMesh:
	var art := settings()
	var units: Dictionary = art.get("unit_models", {})
	if not units.has(unit_id):
		push_error("combat art: no model for unit %s" % unit_id)
		return null
	var filename := "unit_%s" % units[unit_id]
	var base := mesh(filename, true)
	var crests: Dictionary = art.get("crests", {})
	if base == null or not crests.has(house) or not _anchors.has(filename):
		return base
	var key := "%s_%s_animated" % [filename, house]
	if _meshes.has(key):
		return _meshes[key]
	var crest := mesh(str(crests[house]), true)
	if crest == null:
		return base
	var result := ArrayMesh.new()
	for surface: int in base.get_surface_count():
		result.add_surface_from_arrays(
			base.surface_get_primitive_type(surface), base.surface_get_arrays(surface)
		)
		result.surface_set_material(surface, base.surface_get_material(surface))
	for surface: int in crest.get_surface_count():
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.append_from(crest, surface, _anchors[filename])
		builder.commit(result)
		result.surface_set_material(
			result.get_surface_count() - 1, crest.surface_get_material(surface)
		)
	_meshes[key] = result
	return result


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
	if node.name == "crest_anchor":
		_anchors[filename] = transform
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
					var slot: int = HOUSE_SLOTS.get(material.resource_name if material else "", 0)
					material = _shader_material(material, MOTION, "animation")
					material.set_shader_parameter("house_slot", slot)
					material.next_pass = outline()
				elif material != null and material.resource_name == "water":
					material = _shader_material(material, WATER, "water")
				elif filename == "terrain_path":
					material = _shader_material(material, PATH, "path")
				elif filename.begins_with("tree_") or (
					filename.begins_with("foliage_") and filename != "foliage_stump"
				):
					material = _shader_material(material, WIND, "wind")
				elif material is BaseMaterial3D:
					material = _toon(material as BaseMaterial3D)
				result.surface_set_material(result.get_surface_count() - 1, material)
	for child: Node in node.get_children():
		_collect(child, transform, result, animated, filename)


## Ink outline pass shared by every figure surface, moving like the figure itself.
static func outline() -> ShaderMaterial:
	if _outline == null:
		_outline = _shader_material(null, OUTLINE, "animation")
		var ink: Dictionary = settings().get("ink", {})
		var color := Color.from_string(str(ink.get("color", "#211710")), Color.BLACK)
		_outline.set_shader_parameter("width", float(ink.get("outline_width", 0.035)))
		_outline.set_shader_parameter("ink", color)
	return _outline


## Scenery from Blender keeps its colours but takes two-step toon light.
static func _toon(source: BaseMaterial3D) -> BaseMaterial3D:
	var material := source.duplicate() as BaseMaterial3D
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


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
