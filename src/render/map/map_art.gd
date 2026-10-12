class_name MapArt
extends RefCounted
## Presentation values of the map table from data/map_art.json, plus the shared materials
## built from them.

const PATH := "res://data/map_art.json"
const OUTLINE := preload("res://src/render/map/map_outline.gdshader")

static var _art: Dictionary = {}
static var _paints: Dictionary[String, StandardMaterial3D] = {}
static var _outline: ShaderMaterial


static func settings() -> Dictionary:
	if _art.is_empty():
		var data: Variant = DataReader.load_json(PATH)
		if data is Dictionary:
			_art = data
		else:
			push_error("map art: expected a settings object")
	return _art


static func section(key: String) -> Dictionary:
	var value: Variant = settings().get(key, {})
	return value if value is Dictionary else {}


static func number(section_key: String, key: String, fallback: float) -> float:
	return float(section(section_key).get(key, fallback))


static func color(section_key: String, key: String, fallback: Color) -> Color:
	return Color.from_string(str(section(section_key).get(key, "")), fallback)


static func km_per_unit() -> float:
	return float(settings().get("km_per_unit", 10.0))


## Field colour of an owner: the house's heraldic field, or the colour of a lord without house.
static func owner_color(map: MapData, owner: String) -> Color:
	if map.house_colors.has(owner) and not map.house_colors[owner].is_empty():
		return map.house_colors[owner][0]
	return color("owners", owner, Color(0.6, 0.56, 0.45))


## Charge colour of an owner; lords without a house carry gold.
static func charge_color(map: MapData, owner: String) -> Color:
	if map.house_colors.has(owner) and map.house_colors[owner].size() > 1:
		return map.house_colors[owner][1]
	return color("pieces", "gold", Color(0.85, 0.66, 0.24))


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


static func flat(value: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = value
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if value.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
