class_name SiegeArt
extends RefCounted
## Presentation values of the trebuchet minigame from data/combat_siege_art.json and the meshes
## it shows: castle kit pieces (assets/economy/, via CastleArt, with the owner's colours), the
## siege kit and scenery (assets/combat/, via BattleModels, with toon light).

const PATH := "res://data/combat_siege_art.json"
const ECONOMY_PREFIXES: Array[String] = ["castle_", "settlement_", "building_"]

static var _art: Dictionary = {}


static func settings() -> Dictionary:
	if _art.is_empty():
		var data: Variant = DataReader.load_json(PATH)
		if data is Dictionary:
			_art = data
		else:
			push_error("siege art: expected a settings object in %s" % PATH)
	return _art


static func section(key: String) -> Dictionary:
	var value: Variant = settings().get(key, {})
	return value if value is Dictionary else {}


static func number(section_key: String, key: String, fallback: float) -> float:
	return float(section(section_key).get(key, fallback))


static func color(section_key: String, key: String, fallback: Color) -> Color:
	return Color.from_string(str(section(section_key).get(key, "")), fallback)


static func mesh(piece: String) -> ArrayMesh:
	for prefix: String in ECONOMY_PREFIXES:
		if piece.begins_with(prefix):
			return CastleArt.mesh(piece)
	return BattleModels.mesh(piece)


## Field and charge colour of a house or lord; earth tones for lords without heraldry.
static func house_colors(map: MapData, owner: String) -> PackedColorArray:
	var colors: PackedColorArray = map.heraldry().get(owner, PackedColorArray())
	if colors.size() >= 2:
		return colors
	return PackedColorArray([
		CastleArt.color("colors", "neutral_primary", Color.GRAY),
		CastleArt.color("colors", "neutral_secondary", Color.WHEAT),
	])


static func has_house_colors(piece: String) -> bool:
	return piece.begins_with("castle_") and CastleArt.has_house_colors(piece)


## A placement scale: one number, or [x, y, z].
static func scale_of(value: Variant) -> Vector3:
	if value is Array:
		return CastleArt.vector(value, Vector3.ONE)
	if value is float or value is int:
		return Vector3.ONE * float(value)
	return Vector3.ONE


static func vector(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	return CastleArt.vector(value, fallback)


## Mesh instance of a piece with its yaw (degrees about Y) and scale.
static func instance(piece: String, yaw_deg: float, scale: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = piece
	node.mesh = mesh(piece)
	node.basis = Basis(Vector3.UP, deg_to_rad(yaw_deg)).scaled_local(scale)
	return node
