class_name CastleArt
extends RefCounted
## Presentation values of the castle view from data/castle_art.json and the meshes of the castle
## kit (assets/economy/<piece>.glb, built by art-src/economy/). Pieces keep their Blender colours
## with two-step toon light; the white house_primary / house_secondary masks take the owner's
## colours through castle_piece.gdshader's instance uniforms.

const PATH := "res://data/castle_art.json"
const DIRECTORY := "res://assets/economy/"
const PIECE_SHADER := preload("res://src/render/castle/castle_piece.gdshader")
const HOUSE_SLOTS: Dictionary[String, int] = {"house_primary": 1, "house_secondary": 2}
const GLASS_PREFIX := "castle_glass"

static var _art: Dictionary = {}
static var _meshes: Dictionary[String, ArrayMesh] = {}
static var _materials: Dictionary[String, Material] = {}
static var _puff: StandardMaterial3D


static func settings() -> Dictionary:
	if _art.is_empty():
		var data: Variant = DataReader.load_json(PATH)
		if data is Dictionary:
			_art = data
		else:
			push_error("castle art: expected a settings object in %s" % PATH)
	return _art


static func section(key: String) -> Dictionary:
	var value: Variant = settings().get(key, {})
	return value if value is Dictionary else {}


static func number(section_key: String, key: String, fallback: float) -> float:
	return float(section(section_key).get(key, fallback))


static func color(section_key: String, key: String, fallback: Color) -> Color:
	return Color.from_string(str(section(section_key).get(key, "")), fallback)


static func vector(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Array and (value as Array).size() == 3:
		var items: Array = value
		return Vector3(float(items[0]), float(items[1]), float(items[2]))
	return fallback


## The entries of a level-keyed table: those under the highest key not above `level`.
static func for_level(table: Dictionary, level: int) -> Array:
	var best := -1
	for key: Variant in table:
		var number_key := str(key).to_int()
		if number_key <= level and number_key > best:
			best = number_key
	var entries: Variant = table.get(str(best), [])
	return entries if entries is Array else []


## One piece of the kit as a single mesh with game materials, cached per piece.
static func mesh(piece: String) -> ArrayMesh:
	if _meshes.has(piece):
		return _meshes[piece]
	var path := DIRECTORY + piece + ".glb"
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("castle art: cannot load %s" % path)
		return null
	var root := scene.instantiate()
	var result := ArrayMesh.new()
	_collect(root, Transform3D.IDENTITY, result)
	root.free()
	if result.get_surface_count() == 0:
		push_error("castle art: no mesh surfaces in %s" % path)
		return null
	_meshes[piece] = result
	return result


## Soft round billboard for dust and smoke particles, tinted by the particle colour.
static func puff() -> StandardMaterial3D:
	if _puff != null:
		return _puff
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	_puff = StandardMaterial3D.new()
	_puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_puff.vertex_color_use_as_albedo = true
	_puff.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_puff.albedo_texture = texture
	return _puff


## Whether the piece has surfaces in the owner's colours (instance uniforms to set).
static func has_house_colors(piece: String) -> bool:
	var piece_mesh := mesh(piece)
	if piece_mesh == null:
		return false
	for surface: int in piece_mesh.get_surface_count():
		var material := piece_mesh.surface_get_material(surface) as ShaderMaterial
		if material != null and material.shader == PIECE_SHADER:
			return true
	return false


static func _collect(node: Node, parent: Transform3D, result: ArrayMesh) -> void:
	var transform := parent
	if node is Node3D:
		transform *= (node as Node3D).transform
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		for surface: int in instance.mesh.get_surface_count():
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.append_from(instance.mesh, surface, transform)
			builder.commit(result)
			result.surface_set_material(
				result.get_surface_count() - 1, _material(instance.get_active_material(surface))
			)
	for child: Node in node.get_children():
		_collect(child, transform, result)


## Game material for a Blender material, shared by every piece using the same name.
static func _material(source: Material) -> Material:
	var name := source.resource_name if source != null else ""
	if _materials.has(name):
		return _materials[name]
	var result: Material
	if HOUSE_SLOTS.has(name):
		var house := ShaderMaterial.new()
		house.shader = PIECE_SHADER
		house.set_shader_parameter("house_slot", HOUSE_SLOTS[name])
		result = house
	elif source is BaseMaterial3D:
		var toon := source.duplicate() as BaseMaterial3D
		toon.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		toon.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if name.begins_with(GLASS_PREFIX):
			toon.emission_enabled = true
			toon.emission = toon.albedo_color
			toon.emission_energy_multiplier = number("colors", "glass_emission", 0.6)
		result = toon
	else:
		result = source
	_materials[name] = result
	return result
