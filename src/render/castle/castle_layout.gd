class_name CastleLayout
extends RefCounted
## What the castle view of one province shows, worked out from the game state alone: castle
## pieces of its level, the owner's decorations (home castle only), its buildings, the village
## and every construction with its progress, scaffolding and site props.

enum Kind { CASTLE, DECORATION, BUILDING, HOUSE, SCAFFOLD, SITE }


class Placement:
	var piece: String
	var kind: Kind
	var transform: Transform3D
	## Building or decoration id; "" for castle pieces, houses and construction props.
	var source: String = ""
	## 1 when standing; less while under construction (1 - rounds_left / build_rounds).
	var progress: float = 1.0

	func key() -> String:
		return "%s:%s@%s" % [Kind.keys()[kind], piece, transform.origin.snappedf(0.1)]


var province_id: String
## House or other lord holding the province.
var owner: String
var is_owned_by_house: bool
var is_home: bool
var level: int
## tr() key of the castle's name.
var name_key: String
## Settlement and yard key in data/castle_art.json ("home_<level>" or "province_<level>").
var site_key: String
var primary: Color
var secondary: Color
var placements: Array[Placement] = []


static func plan(state: GameState, rules: GameRules, province_id: String) -> CastleLayout:
	var province: ProvinceState = state.provinces.get(province_id)
	if province == null:
		push_error("castle view: unknown province %s" % province_id)
		return null
	var layout := CastleLayout.new()
	layout.province_id = province_id
	layout.owner = province.owner
	var house: HouseState = state.houses.get(province.owner)
	layout.is_owned_by_house = house != null
	layout.is_home = house != null and BuildingRules.is_home(state, house.id, province_id)
	layout._set_colors(rules.map, province.owner)
	var home_table := CastleArt.section("home_castle")
	var province_table := CastleArt.section("province_castle")
	# A conquered home castle keeps its stones: levels beyond the province table use the home kit.
	var home_kit := layout.is_home or not province_table.has(str(province.castle_level))
	layout.level = clampi(province.castle_level, 1 if home_kit else 0, 5 if home_kit else 3)
	var table := home_table if home_kit else province_table
	layout.name_key = "ECONOMY_%s_CASTLE_%d" % ["HOME" if home_kit else "PROVINCE", layout.level]
	layout.site_key = "%s_%d" % ["home" if home_kit else "province", layout.level]
	var castle := layout._entries(table.get(str(layout.level), []))
	for entry: Dictionary in castle:
		layout._add(entry, Kind.CASTLE, "", 1.0)
	if layout.is_home:
		layout._add_decorations(house, rules.economy)
	layout._add_buildings(province, rules.economy)
	layout._add_castle_construction(state, rules.economy, province, table, castle)
	layout._add_settlement(province.population)
	return layout


func pieces_of(kind: Kind) -> Array[Placement]:
	var result: Array[Placement] = []
	for placement: Placement in placements:
		if placement.kind == kind:
			result.append(placement)
	return result


func _set_colors(map: MapData, owner: String) -> void:
	var colors: PackedColorArray = map.heraldry().get(owner, PackedColorArray())
	primary = (
		colors[0] if colors.size() > 0
		else CastleArt.color("colors", "neutral_primary", Color.GRAY)
	)
	secondary = (
		colors[1] if colors.size() > 1
		else CastleArt.color("colors", "neutral_secondary", Color.WHEAT)
	)


func _add_decorations(house: HouseState, economy: EconomyConfig) -> void:
	var tables := CastleArt.section("decorations")
	for id: String in house.decorations:
		var def: DecorationDef = economy.decorations.get(id)
		if def != null and def.home_castle > level:
			continue
		var table: Variant = tables.get(id, {})
		if not table is Dictionary:
			continue
		for entry: Dictionary in _entries(CastleArt.for_level(table, level)):
			_add(entry, Kind.DECORATION, id, 1.0)


func _add_buildings(province: ProvinceState, economy: EconomyConfig) -> void:
	for id: String in province.buildings:
		_add_building(id, 1.0)
	for construction: ConstructionState in province.constructions:
		var def: BuildingDef = economy.buildings.get(construction.project)
		if def != null:
			_add_building(construction.project, _progress(construction, def.build_rounds))


func _add_building(id: String, progress: float) -> void:
	var entries := _entries(CastleArt.section("buildings").get(id, []))
	if entries.is_empty():
		push_error("castle view: no art for building %s" % id)
	for entry: Dictionary in entries:
		_add(entry, Kind.BUILDING, id, progress)


## The next castle level under construction: its new pieces, partly raised.
func _add_castle_construction(
	state: GameState, economy: EconomyConfig, province: ProvinceState, table: Dictionary,
	current: Array[Dictionary]
) -> void:
	for construction: ConstructionState in province.constructions:
		if construction.project != ConstructionState.CASTLE:
			continue
		var levels := (
			BuildingRules.castle_table(state, economy, province.owner, province_id)
			if state.houses.has(province.owner) else economy.province_castle
		)
		var next: CastleLevelDef = levels.get(province.castle_level + 1)
		if next == null or not table.has(str(level + 1)):
			continue
		var progress := _progress(construction, next.build_rounds)
		for entry: Dictionary in _entries(table[str(level + 1)]):
			if not _has_entry(current, entry):
				_add(entry, Kind.CASTLE, ConstructionState.CASTLE, progress)


func _add_settlement(population: float) -> void:
	var settlement := CastleArt.section("settlement")
	var radii: Dictionary = settlement.get("inner_radius", {})
	var keep_outs: Array[Vector3] = []
	for placement: Placement in pieces_of(Kind.BUILDING):
		var at := placement.transform.origin
		keep_outs.append(Vector3(at.x, at.z, _clear_radius(placement)))
	var count := CastleSettlement.house_count(population)
	for lot: CastleSettlement.Lot in CastleSettlement.lots(
		count, float(radii.get(site_key, 25.0)), keep_outs
	):
		var placement := Placement.new()
		placement.piece = lot.piece
		placement.kind = Kind.HOUSE
		placement.transform = lot.transform
		placements.append(placement)


func _clear_radius(building: Placement) -> float:
	for entry: Dictionary in _entries(CastleArt.section("buildings").get(building.source, [])):
		if entry.get("piece", "") == building.piece:
			return float(entry.get("clear", 8.0))
	return 8.0


func _add(entry: Dictionary, kind: Kind, source: String, progress: float) -> void:
	var placement := Placement.new()
	placement.piece = str(entry.get("piece", ""))
	placement.kind = kind
	placement.source = source
	placement.progress = progress
	var scale := float(entry.get("scale", 1.0))
	var basis := Basis(Vector3.UP, deg_to_rad(float(entry.get("yaw", 0.0)))).scaled(
		Vector3.ONE * scale
	)
	placement.transform = Transform3D(basis, CastleArt.vector(entry.get("at")))
	placements.append(placement)
	if progress < 1.0:
		CastleConstruction.add_props(self, placement)


static func _progress(construction: ConstructionState, build_rounds: int) -> float:
	if build_rounds <= 0:
		return 1.0
	return clampf(1.0 - float(construction.rounds_left) / build_rounds, 0.0, 1.0)


static func _has_entry(entries: Array[Dictionary], entry: Dictionary) -> bool:
	for other: Dictionary in entries:
		if other.get("piece") == entry.get("piece") and other.get("at") == entry.get("at"):
			return true
	return false


static func _entries(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item: Variant in value:
			if item is Dictionary:
				result.append(item)
	return result
