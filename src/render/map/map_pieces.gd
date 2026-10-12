class_name MapPieces
extends Node3D
## The pieces standing on the fields: house banners, castles by level, occupation tokens and
## one painted wooden figure per army with its company count.

const NO_ARMY := -1

var _map: MapData
var _board: MapBoard
var _banners: Dictionary[String, MeshInstance3D] = {}
var _castles: Dictionary[String, MeshInstance3D] = {}
var _tokens: Dictionary[String, MeshInstance3D] = {}
var _figures: Dictionary[int, MapFigure] = {}
var _selected_army: int = NO_ARMY


func setup(map: MapData, board: MapBoard) -> void:
	_map = map
	_board = board
	var pieces := MapArt.section("pieces")
	for id: String in board.cells:
		_banners[id] = _place("Banner_" + id, MapPieceMeshes.banner(), id, pieces, "banner")
		_castles[id] = _place("Castle_" + id, null, id, pieces, "castle")
		_tokens[id] = _place("Occupied_" + id, MapPieceMeshes.occupied_token(), id, pieces,
			"occupied")
		var token_paint: Array[Color] = [
			MapArt.color("pieces", "occupied", Color.DARK_RED),
			MapArt.color("sheet", "paper", Color.WHEAT),
		]
		_paint(_tokens[id], token_paint)


func update_view(state: GameState) -> void:
	for id: String in _banners:
		var province: ProvinceState = state.provinces.get(id)
		var owner := province.owner if province != null else ""
		var is_house := _map.house_colors.has(owner)
		_banners[id].visible = is_house
		if is_house:
			_paint(_banners[id], _owner_paints(owner))
		var level := province.castle_level if province != null else 0
		_castles[id].visible = level > 0
		if level > 0:
			_castles[id].mesh = MapPieceMeshes.castle(mini(level, 5))
			var castle_paint: Array[Color] = [
				MapArt.color("pieces", "stone", Color.GRAY), MapArt.owner_color(_map, owner),
			]
			_paint(_castles[id], castle_paint)
		_tokens[id].visible = province != null and province.occupied_rounds > 0
	_update_armies(state)


func set_selected_army(army_id: int) -> void:
	_selected_army = army_id
	for id: int in _figures:
		_figures[id].set_selected(id == army_id)


## The army whose figure the ray hits first, or NO_ARMY.
func army_on_ray(origin: Vector3, direction: Vector3) -> int:
	var best := NO_ARMY
	var nearest := INF
	var far := origin + direction.normalized() * 10000.0
	for id: int in _figures:
		var figure := _figures[id]
		var hits := Geometry3D.get_closest_points_between_segments(
			origin, far, figure.foot(), figure.head()
		)
		if hits[0].distance_to(hits[1]) <= figure.radius() and origin.distance_to(hits[0]) < nearest:
			nearest = origin.distance_to(hits[0])
			best = id
	return best


func figure_count() -> int:
	return _figures.size()


func _update_armies(state: GameState) -> void:
	var by_province: Dictionary[String, Array] = {}
	var alive: Dictionary[int, bool] = {}
	for army: ArmyState in state.armies:
		if not _board.cells.has(army.province):
			continue
		if not by_province.has(army.province):
			by_province[army.province] = []
		by_province[army.province].append(army)
		alive[army.id] = true
	for id: int in _figures.keys():
		if not alive.has(id):
			_figures[id].queue_free()
			_figures.erase(id)
	var spacing := MapArt.number("pieces", "figure_spacing", 1.9)
	for province_id: String in by_province:
		var group: Array = by_province[province_id]
		group.sort_custom(func(a: ArmyState, b: ArmyState) -> bool: return a.id < b.id)
		var base := _board.world_position(province_id)
		for i: int in group.size():
			var army := group[i] as ArmyState
			if not _figures.has(army.id):
				var created := MapFigure.new()
				created.name = "Army_%d" % army.id
				add_child(created)
				_figures[army.id] = created
			var figure := _figures[army.id]
			figure.position = base + Vector3((i - (group.size() - 1) * 0.5) * spacing, 0.0, 0.0)
			figure.show_army(army.company_count(), _owner_paints(army.owner))
			figure.set_selected(army.id == _selected_army)


## Paint slots of a house piece (MapPieceMeshes.Slot order).
func _owner_paints(owner: String) -> Array[Color]:
	return [
		MapArt.owner_color(_map, owner), MapArt.charge_color(_map, owner),
		MapArt.color("pieces", "wood", Color.BURLYWOOD),
		MapArt.color("pieces", "wood_dark", Color.SADDLE_BROWN),
		MapArt.color("pieces", "gold", Color.GOLD),
	]


func _place(
	node_name: String, mesh: Mesh, province_id: String, pieces: Dictionary, kind: String
) -> MeshInstance3D:
	var spot: Array = pieces.get(kind + "_spot", [0.0, 0.0, 3.0])
	var direction := Vector2(float(spot[0]), float(spot[1])) if spot.size() == 3 else Vector2.UP
	var distance := float(spot[2]) if spot.size() == 3 else 3.0
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = _board.spot(province_id, direction, distance)
	instance.scale = Vector3.ONE * float(pieces.get(kind + "_scale", 2.4))
	instance.visible = false
	add_child(instance)
	return instance


static func _paint(instance: MeshInstance3D, paints: Array[Color]) -> void:
	if instance.mesh == null:
		return
	for slot: int in mini(instance.mesh.get_surface_count(), paints.size()):
		instance.set_surface_override_material(slot, MapArt.paint(paints[slot]))
