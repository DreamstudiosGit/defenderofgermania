class_name MapArt
extends RefCounted
## Presentation values of the map table from data/map_art.json, plus the shared materials
## built from them.

const PATH := "res://data/map_art.json"
const OUTLINE := preload("res://src/render/map/map_outline.gdshader")
const RIM := preload("res://src/render/map/map_rim.gdshader")
## Rims draw before the ink pass (priority 0), so its grain and vignette lie over them as
## over the fields; left to the depth sort, near rims would draw after it and far ones before.
const RIM_PRIORITY := -1

static var _art: Dictionary = {}
static var _paints: Dictionary[String, StandardMaterial3D] = {}
static var _outline: ShaderMaterial
## Stands in for a missing section; the camera asks every frame, so none is made per call.
static var _no_section: Dictionary = {}


static func settings() -> Dictionary:
	if _art.is_empty():
		var data: Variant = DataReader.load_json(PATH)
		if data is Dictionary:
			_art = data
		else:
			push_error("map art: expected a settings object")
	return _art


static func section(key: String) -> Dictionary:
	var value: Variant = settings().get(key)
	return value if value is Dictionary else _no_section


static func number(section_key: String, key: String, fallback: float) -> float:
	return float(section(section_key).get(key, fallback))


## A value of the "quality" section, which holds one entry per level (UserSettings.Quality).
static func by_quality(key: String, level: int, fallback: Variant) -> Variant:
	var levels: Variant = section("quality").get(key)
	if levels is Array and level >= 0 and level < (levels as Array).size():
		return (levels as Array)[level]
	return fallback


static func color(section_key: String, key: String, fallback: Color) -> Color:
	return Color.from_string(str(section(section_key).get(key, "")), fallback)


static func km_per_unit() -> float:
	return float(settings().get("km_per_unit", 10.0))


## Field colour of an owner: the heraldic field of the house or other lord (MapData.heraldry).
static func owner_color(map: MapData, owner: String) -> Color:
	var colors: PackedColorArray = map.heraldry().get(owner, PackedColorArray())
	return colors[0] if not colors.is_empty() else Color(0.6, 0.56, 0.45)


## Charge colour of an owner; gold when the owner has none.
static func charge_color(map: MapData, owner: String) -> Color:
	var colors: PackedColorArray = map.heraldry().get(owner, PackedColorArray())
	return colors[1] if colors.size() > 1 else color("pieces", "gold", Color(0.85, 0.66, 0.24))


## Painted wood: two-step toon light with the ink outline pass, cached per colour.
static func paint(value: Color) -> StandardMaterial3D:
	var key := value.to_html()
	if _paints.has(key):
		return _paints[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = value
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	material.roughness = 0.55
	material.next_pass = outline()
	_paints[key] = material
	return material


static func outline() -> ShaderMaterial:
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE
		_outline.set_shader_parameter("ink", color("ink", "color", Color.BLACK))
		_outline.set_shader_parameter("width", number("ink", "outline_width", 0.025))
	return _outline


## Flat light for rims and rings (map_rim.gdshader); `breath` is the share of its strength
## that fades out and back in slowly.
static func rim(value: Color, breath: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = RIM
	material.render_priority = RIM_PRIORITY
	material.set_shader_parameter("tint", value)
	material.set_shader_parameter("breath", breath)
	return material


static func flat(value: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = value
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if value.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
