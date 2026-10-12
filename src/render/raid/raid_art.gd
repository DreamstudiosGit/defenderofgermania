class_name RaidArt
extends RefCounted
## Presentation values of the castle raid (data/combat_raid_art.json) and the shared two-step
## toon materials of its castle interior, built from primitives.

const PATH := "res://data/combat_raid_art.json"

static var _art: Dictionary = {}
static var _materials: Dictionary[String, Material] = {}


static func settings() -> Dictionary:
	if _art.is_empty():
		var data: Variant = DataReader.load_json(PATH)
		if data is Dictionary:
			_art = data
		else:
			push_error("raid art: expected a settings object in %s" % PATH)
	return _art


static func section(key: String) -> Dictionary:
	var value: Variant = settings().get(key, {})
	return value if value is Dictionary else {}


static func number(section_key: String, key: String, fallback: float) -> float:
	var value: Variant = section(section_key).get(key, fallback)
	return float(value) if value is float or value is int else fallback


static func color(key: String, fallback: Color = Color.MAGENTA) -> Color:
	return Color.from_string(str(section("colors").get(key, "")), fallback)


static func light_color(key: String, fallback: Color = Color.WHITE) -> Color:
	return Color.from_string(str(section("light").get(key, "")), fallback)


static func list(section_key: String, key: String) -> Array:
	var value: Variant = section(section_key).get(key, [])
	return value if value is Array else []


## Matte toon material in one of the palette colours (or any colour), shared per colour.
static func material(color_key: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var cache_key := "%s/%s" % [color_key, tint.to_html()]
	if _materials.has(cache_key):
		return _materials[cache_key] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.albedo_color = color(color_key) * tint
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	result.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	result.roughness = 1.0
	_materials[cache_key] = result
	return result


## Toon material whose albedo comes from per-instance colours (masonry, coins, sacks).
static func instance_material() -> StandardMaterial3D:
	if _materials.has("instances"):
		return _materials["instances"] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	result.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	result.roughness = 1.0
	_materials["instances"] = result
	return result


## Unshaded glowing material: flames, moonlit glass, embers.
static func glow(color_value: Color, energy: float) -> StandardMaterial3D:
	var cache_key := "glow/%s/%.2f" % [color_value.to_html(), energy]
	if _materials.has(cache_key):
		return _materials[cache_key] as StandardMaterial3D
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.albedo_color = color_value
	result.emission_enabled = true
	result.emission = color_value
	result.emission_energy_multiplier = energy
	_materials[cache_key] = result
	return result


## A box mesh instance with a palette material, positioned by its centre.
static func box(size: Vector3, center: Vector3, color_key: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color_key)
	instance.position = center
	return instance


static func cylinder(
	radius: float, height: float, center: Vector3, color_key: String
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color_key)
	instance.position = center
	return instance
