class_name MapTable
extends Node3D
## The imperial map as a candlelit war-table diorama (presentation only). build() lays out the
## table from MapData once; update_view() paints owners, banners, castles and army figures from
## a GameState; province_at() / army_at() and the signals map the screen back to the game.

## Left click on a field without an army figure under the cursor.
signal province_clicked(province_id: String)
## Left click on an army figure.
signal army_clicked(army_id: int)
## The cursor moved onto another province ("" off the realm).
signal province_hovered(province_id: String)

const NO_ARMY := -1

var camera := MapCamera.new()

var _map: MapData
var _board := MapBoard.new()
var _pieces := MapPieces.new()
var _hovered: String = ""


func build(map: MapData) -> void:
	if _map != null:
		push_error("map table: build() runs only once")
		return
	_map = map
	MapInputMap.register()
	_board.name = "Board"
	add_child(_board)
	_board.build(map)
	var surroundings := MapSurroundings.new()
	surroundings.name = "Surroundings"
	add_child(surroundings)
	surroundings.build(map, _board)
	var labels := MapLabels.new()
	labels.name = "Labels"
	add_child(labels)
	labels.build(_board)
	var props := MapProps.new()
	props.name = "Props"
	add_child(props)
	props.build(map, _board, labels.areas)
	_pieces.name = "Pieces"
	add_child(_pieces)
	_pieces.setup(map, _board)
	var lighting := MapLighting.new()
	lighting.name = "Lighting"
	add_child(lighting)
	lighting.build(surroundings.table)
	var anchors: Dictionary[String, Vector3] = {}
	for id: String in _board.cells:
		anchors[id] = _board.world_position(id)
	camera.name = "Camera"
	add_child(camera)
	var ground := _board.sheet_top + MapArt.number("field", "base_height", 0.5)
	camera.setup(_board.bounds, anchors, ground)
	camera.current = true
	if DisplayServer.get_name() != "headless":
		add_child(MapInk.new())


func update_view(state: GameState) -> void:
	if _map == null:
		push_error("map table: update_view() before build()")
		return
	_board.paint(_map, state)
	_pieces.update_view(state)


## Selected province ("" for none), selected army (-1 for none) and reachable provinces.
func set_selection(province_id: String, army_id: int, highlights: Array[String]) -> void:
	_board.set_selection(province_id, highlights)
	_pieces.set_selected_army(army_id)


## The province under the screen position, seen through the active camera; "" off the realm.
func province_at(screen_position: Vector2) -> String:
	var view := _active_camera()
	var found := ""
	var highest := -INF
	# The ray meets the highest field first; test each field at its own height.
	for id: String in _board.cells:
		var height := _board.heights[id]
		if height <= highest:
			continue
		var point := MapCamera.table_point(view, screen_position, height)
		if point.is_finite() and Geometry2D.is_point_in_polygon(point, _board.cells[id]):
			found = id
			highest = height
	return found


## The army whose figure is under the screen position, or -1.
func army_at(screen_position: Vector2) -> int:
	var view := _active_camera()
	return _pieces.army_on_ray(
		view.project_ray_origin(screen_position), view.project_ray_normal(screen_position)
	)


## Centre of the province's field on the table top.
func world_position(province_id: String) -> Vector3:
	return _board.world_position(province_id)


func field_count() -> int:
	return _board.field_count()


func figure_count() -> int:
	return _pieces.figure_count()


func _unhandled_input(event: InputEvent) -> void:
	if _map == null:
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		var army := army_at(button.position)
		if army != NO_ARMY:
			army_clicked.emit(army)
		else:
			var province := province_at(button.position)
			if not province.is_empty():
				province_clicked.emit(province)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var hovered := province_at(motion.position)
		if hovered != _hovered:
			_hovered = hovered
			province_hovered.emit(hovered)


func _active_camera() -> Camera3D:
	var active: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return active if active != null else camera
