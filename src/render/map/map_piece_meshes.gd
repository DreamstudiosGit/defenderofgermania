class_name MapPieceMeshes
extends RefCounted
## The carved and painted wooden pieces of the map table, about one unit tall before scaling.
## Each mesh has one surface per paint slot; MapPieces paints the slots per owner.

enum Slot { FIELD, CHARGE, WOOD, DARK_WOOD, GOLD }
enum CastleSlot { STONE, ROOF }
enum PropSlot { MAIN, ACCENT }

static var _cache: Dictionary[String, ArrayMesh] = {}


## A knight on a turned stand: field-coloured surcoat, charge-coloured helm and shield,
## a lance with a pennant.
static func figure() -> ArrayMesh:
	if _cache.has("figure"):
		return _cache["figure"]
	var parts := MapMeshes.Assembly.new(Slot.size())
	parts.add(Slot.DARK_WOOD, MapMeshes.cylinder(0.33, 0.36, 0.09, 16), _up(0.045))
	parts.add(Slot.FIELD, MapMeshes.cylinder(0.16, 0.27, 0.42), _up(0.3))
	parts.add(Slot.FIELD, MapMeshes.sphere(0.2, 0.34), _up(0.64))
	parts.add(Slot.FIELD, MapMeshes.sphere(0.075, 0.1), _up(1.0))
	parts.add(Slot.CHARGE, MapMeshes.cylinder(0.18, 0.18, 0.05), _up(0.5))
	parts.add(Slot.CHARGE, MapMeshes.cylinder(0.12, 0.135, 0.2), _up(0.86))
	parts.add(Slot.DARK_WOOD, MapMeshes.box(Vector3(0.18, 0.025, 0.04)),
		MapMeshes.at(Vector3(0.0, 0.89, 0.115)))
	parts.add(Slot.CHARGE, MapMeshes.box(Vector3(0.27, 0.33, 0.05)),
		MapMeshes.at(Vector3(-0.1, 0.45, 0.2), -15.0))
	parts.add(Slot.FIELD, MapMeshes.box(Vector3(0.08, 0.33, 0.056)),
		MapMeshes.at(Vector3(-0.1, 0.45, 0.2), -15.0))
	parts.add(Slot.WOOD, MapMeshes.cylinder(0.022, 0.022, 1.25, 6),
		MapMeshes.at(Vector3(0.25, 0.64, 0.04)))
	parts.add(Slot.GOLD, MapMeshes.sphere(0.03, 0.06), MapMeshes.at(Vector3(0.25, 1.28, 0.04)))
	parts.add(Slot.FIELD, MapMeshes.wedge(Vector3(0.16, 0.32, 0.015)),
		MapMeshes.at(Vector3(0.41, 1.16, 0.04), 0.0, -90.0))
	return _keep("figure", parts.commit())


## A house banner on a standing pole: field-coloured cloth with a charge-coloured pale.
static func banner() -> ArrayMesh:
	if _cache.has("banner"):
		return _cache["banner"]
	var parts := MapMeshes.Assembly.new(Slot.size())
	parts.add(Slot.FIELD, MapMeshes.box(Vector3(0.5, 0.34, 0.025)),
		MapMeshes.at(Vector3(0.27, 1.06, 0.0)))
	parts.add(Slot.CHARGE, MapMeshes.box(Vector3(0.12, 0.34, 0.03)),
		MapMeshes.at(Vector3(0.27, 1.06, 0.0)))
	parts.add(Slot.FIELD, MapMeshes.wedge(Vector3(0.17, 0.12, 0.025)),
		MapMeshes.at(Vector3(0.58, 0.95, 0.0), 0.0, -90.0))
	parts.add(Slot.WOOD, MapMeshes.cylinder(0.025, 0.03, 1.3, 8), _up(0.65))
	parts.add(Slot.DARK_WOOD, MapMeshes.cylinder(0.12, 0.14, 0.07, 12), _up(0.035))
	parts.add(Slot.GOLD, MapMeshes.sphere(0.05, 0.1), _up(1.33))
	return _keep("banner", parts.commit())


## A castle that grows with its level: towers, curtain walls and from level 3 a keep.
static func castle(level: int) -> ArrayMesh:
	var key := "castle_%d" % level
	if _cache.has(key):
		return _cache[key]
	var parts := MapMeshes.Assembly.new(CastleSlot.size())
	var towers := level if level < 3 else level - 1
	var spots := PackedVector2Array()
	for i: int in towers:
		var angle := TAU * i / towers + PI * 0.75
		var radius := 0.0 if towers == 1 else 0.24 + 0.03 * towers
		spots.append(Vector2(cos(angle), sin(angle)) * radius)
	for i: int in spots.size():
		var height := 0.42 + 0.04 * level
		_tower(parts, spots[i], 0.1 + 0.012 * level, height)
		if spots.size() > 1 and (towers > 2 or i == 0):
			_wall(parts, spots[i], spots[(i + 1) % spots.size()], height * 0.5)
	if level >= 3:
		var keep := Vector3(0.24, 0.5 + 0.06 * level, 0.24)
		parts.add(CastleSlot.STONE, MapMeshes.box(keep), _up(keep.y * 0.5))
		parts.add(CastleSlot.ROOF, MapMeshes.cylinder(0.0, 0.2, 0.22, 4),
			MapMeshes.at(Vector3(0.0, keep.y + 0.11, 0.0), 45.0))
	return _keep(key, parts.commit())


## A token for an occupied province: a dark disc with a crossed pair of stakes.
static func occupied_token() -> ArrayMesh:
	if _cache.has("occupied"):
		return _cache["occupied"]
	var parts := MapMeshes.Assembly.new(PropSlot.size())
	parts.add(PropSlot.MAIN, MapMeshes.cylinder(0.22, 0.24, 0.07, 14), _up(0.035))
	for yaw: float in [45.0, -45.0]:
		parts.add(PropSlot.ACCENT, MapMeshes.box(Vector3(0.32, 0.04, 0.06)),
			MapMeshes.at(Vector3(0.0, 0.08, 0.0), yaw))
	return _keep("occupied", parts.commit())


## Terrain props: main colour first, accent second.
static func prop(kind: String) -> ArrayMesh:
	var key := "prop_" + kind
	if _cache.has(key):
		return _cache[key]
	var parts := MapMeshes.Assembly.new(PropSlot.size())
	match kind:
		"forest":
			parts.add(PropSlot.MAIN, MapMeshes.cylinder(0.0, 0.32, 0.8, 7), _up(0.62))
			parts.add(PropSlot.ACCENT, MapMeshes.cylinder(0.06, 0.07, 0.25, 5), _up(0.12))
		"mountains":
			parts.add(PropSlot.MAIN, MapMeshes.cylinder(0.0, 0.85, 1.1, 6), _up(0.55))
			parts.add(PropSlot.ACCENT, MapMeshes.cylinder(0.0, 0.3, 0.39, 6), _up(0.92))
		"hills":
			parts.add(PropSlot.MAIN, MapMeshes.sphere(0.75, 1.0, true), _up(0.0))
			parts.add(PropSlot.ACCENT, MapMeshes.sphere(0.45, 0.6, true),
				MapMeshes.at(Vector3(0.55, 0.0, 0.3)))
		"marsh":
			for i: int in 4:
				var lean := -18.0 + 12.0 * i
				parts.add(PropSlot.MAIN, MapMeshes.cylinder(0.015, 0.03, 0.55, 4),
					MapMeshes.at(Vector3(-0.15 + 0.1 * i, 0.26, 0.04 * i), 30.0 * i, lean))
			parts.add(PropSlot.ACCENT, MapMeshes.cylinder(0.3, 0.32, 0.02, 10), _up(0.01))
		"heath":
			parts.add(PropSlot.MAIN, MapMeshes.sphere(0.24, 0.3), _up(0.12))
			parts.add(PropSlot.ACCENT, MapMeshes.sphere(0.16, 0.2),
				MapMeshes.at(Vector3(0.25, 0.08, 0.1)))
		_:
			parts.add(PropSlot.MAIN, MapMeshes.box(Vector3(0.4, 0.3, 0.34)), _up(0.15))
			parts.add(PropSlot.ACCENT, MapMeshes.wedge(Vector3(0.46, 0.22, 0.38)), _up(0.41))
	return _keep(key, parts.commit())


static func _tower(parts: MapMeshes.Assembly, spot: Vector2, radius: float, height: float) -> void:
	parts.add(CastleSlot.STONE, MapMeshes.cylinder(radius, radius * 1.08, height, 10),
		MapMeshes.at(Vector3(spot.x, height * 0.5, spot.y)))
	parts.add(CastleSlot.ROOF, MapMeshes.cylinder(0.0, radius * 1.3, radius * 1.9, 10),
		MapMeshes.at(Vector3(spot.x, height + radius * 0.95, spot.y)))


static func _wall(parts: MapMeshes.Assembly, from: Vector2, to: Vector2, height: float) -> void:
	var middle := (from + to) * 0.5
	var yaw := rad_to_deg(-(to - from).angle())
	parts.add(CastleSlot.STONE, MapMeshes.box(Vector3(from.distance_to(to), height, 0.07)),
		MapMeshes.at(Vector3(middle.x, height * 0.5, middle.y), yaw))


static func _up(height: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.0, height, 0.0))


static func _keep(key: String, mesh: ArrayMesh) -> ArrayMesh:
	_cache[key] = mesh
	return mesh
