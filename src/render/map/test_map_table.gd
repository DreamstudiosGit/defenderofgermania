extends GutTest
## Province cells of the war table against the realm and the adjacency list, and a headless
## build of the table for a fresh game.

const OVERLAP_KM2 := 1.0
const WOBBLE_OVERLAP_KM2 := 25.0
const MIN_MATCHING_PAIRS := 55
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 800), Vector2i(1920, 1080)]

var _map: MapData
var _cells: Dictionary[String, PackedVector2Array]
var _centres: Dictionary[String, Vector2]


func before_all() -> void:
	_map = MapData.load_file()
	_cells = MapGeometry.province_cells(_map)
	_centres = MapGeometry.centres_km(_map)


func test_every_province_gets_a_cell_around_its_centre() -> void:
	assert_eq(_cells.size(), _map.provinces.size())
	for id: String in _map.provinces:
		assert_true(_cells.has(id), id)
		assert_gte(_cells[id].size(), 3, "%s has a polygon" % id)
		assert_gt(MapGeometry.area(_cells[id]), 1000.0, "%s is not a sliver" % id)
		assert_true(Geometry2D.is_point_in_polygon(_centres[id], _cells[id]), "%s centre" % id)


func test_cells_do_not_overlap() -> void:
	_assert_no_overlap(_cells, OVERLAP_KM2)


func test_cells_stay_inside_the_realm_and_cover_it() -> void:
	var outline := _map.geography.outline_km()
	var total := 0.0
	for id: String in _cells:
		var outside := 0.0
		for piece: PackedVector2Array in Geometry2D.clip_polygons(_cells[id], outline):
			outside += MapGeometry.area(piece)
		assert_lt(outside, OVERLAP_KM2, "%s stays inside" % id)
		total += MapGeometry.area(_cells[id])
	assert_almost_eq(total, MapGeometry.area(outline), MapGeometry.area(outline) * 0.01)


func test_point_lookup_finds_each_province_at_its_centre() -> void:
	for id: String in _centres:
		assert_eq(MapGeometry.cell_at(_cells, _centres[id]), id)
	assert_eq(MapGeometry.cell_at(_cells, Vector2(5000.0, 5000.0)), "", "off the realm")


func test_wobbled_borders_keep_centres_and_do_not_overlap() -> void:
	var art := MapArt.section("border")
	var wobbled := MapGeometry.wobbled_cells(
		_cells, float(art["wobble_amplitude_km"]), float(art["wobble_wavelength_km"]),
		float(art["wobble_step_km"])
	)
	for id: String in _centres:
		assert_eq(MapGeometry.cell_at(wobbled, _centres[id]), id, "%s after the wobble" % id)
	_assert_no_overlap(wobbled, WOBBLE_OVERLAP_KM2)


func test_drawn_neighbours_mostly_match_the_adjacency_list() -> void:
	var drawn := MapGeometry.touching_pairs(_cells)
	var matching := 0
	var missing: Array[String] = []
	for id: String in _map.provinces:
		for other: String in _map.provinces[id].neighbors:
			if id < other:
				if "%s-%s" % [id, other] in drawn:
					matching += 1
				else:
					missing.append("%s-%s" % [id, other])
	var extra: Array[String] = []
	for pair: String in drawn:
		var ids := pair.split("-")
		if not _map.are_neighbors(ids[0], ids[1]):
			extra.append(pair)
	gut.p("drawn borders: %d of %d data pairs, missing %s, extra %s" % [
		matching, _map.connection_count(), missing, extra
	])
	assert_gte(matching, MIN_MATCHING_PAIRS)


func test_table_builds_for_a_fresh_game() -> void:
	var state := GameSetup.create(_map, EconomyConfig.load_file(), 1)
	var table := _table(RESOLUTIONS[0])
	table.update_view(state)
	assert_eq(table.field_count(), _map.provinces.size(), "one field per province")
	assert_eq(table.figure_count(), state.armies.size(), "one figure per army")
	var army := state.armies[0]
	table.set_selection(army.province, army.id, _map.provinces[army.province].neighbors)
	table.set_selection("", MapTable.NO_ARMY, [])
	state.remove_army(army)
	table.update_view(state)
	assert_eq(table.figure_count(), state.armies.size(), "figures follow the armies")


func test_screen_lookup_finds_provinces_and_armies() -> void:
	var state := GameSetup.create(_map, EconomyConfig.load_file(), 1)
	var table := _table(RESOLUTIONS[0])
	table.update_view(state)
	var army_provinces: Array[String] = []
	for army: ArmyState in state.armies:
		army_provinces.append(army.province)
	for id: String in _map.provinces:
		var screen := table.camera.unproject_position(table.world_position(id))
		if id not in army_provinces:
			assert_eq(table.province_at(screen), id, "click on %s" % id)
			assert_eq(table.army_at(screen), MapTable.NO_ARMY, "no army in %s" % id)
	for army: ArmyState in state.armies:
		var foot := table.world_position(army.province)
		var screen := table.camera.unproject_position(foot + Vector3.UP * 2.0)
		assert_eq(table.army_at(screen), army.id, "click on army %d" % army.id)
	assert_eq(table.province_at(Vector2(2.0, 2.0)), "", "the room around the table")


func test_start_view_shows_the_whole_realm() -> void:
	for resolution: Vector2i in RESOLUTIONS:
		var table := _table(resolution)
		var screen := Rect2(Vector2.ZERO, resolution)
		for id: String in _map.provinces:
			var point := table.camera.unproject_position(table.world_position(id))
			assert_true(screen.has_point(point), "%s visible at %s" % [id, resolution])


func test_focus_glides_to_the_province() -> void:
	var table := _table(RESOLUTIONS[0])
	var goal := table.world_position("AAC")
	table.camera.focus("AAC")
	for i: int in 120:
		table.camera._process(1.0 / 60.0)
	assert_almost_eq(table.camera.target.x, goal.x, 0.05)
	assert_almost_eq(table.camera.target.y, goal.z, 0.05)
	assert_lte(table.camera.distance, MapArt.number("camera", "focus_distance", 55.0) + 0.5)


func test_clicks_and_hover_emit_signals() -> void:
	var state := GameSetup.create(_map, EconomyConfig.load_file(), 1)
	var table := _table(RESOLUTIONS[0])
	table.update_view(state)
	watch_signals(table)
	var army := state.armies[0]
	var on_army := table.camera.unproject_position(
		table.world_position(army.province) + Vector3.UP * 2.0
	)
	table._unhandled_input(_click(on_army))
	assert_signal_emitted_with_parameters(table, "army_clicked", [army.id])
	assert_signal_not_emitted(table, "province_clicked", "a figure takes the click")
	var on_field := table.camera.unproject_position(table.world_position("AAC"))
	table._unhandled_input(_click(on_field))
	assert_signal_emitted_with_parameters(table, "province_clicked", ["AAC"])
	var motion := InputEventMouseMotion.new()
	motion.position = on_field
	table._unhandled_input(motion)
	table._unhandled_input(motion)
	assert_signal_emitted_with_parameters(table, "province_hovered", ["AAC"])
	assert_signal_emit_count(table, "province_hovered", 1, "only when the province changes")


func test_camera_pans_and_zooms_within_limits() -> void:
	var table := _table(RESOLUTIONS[0])
	var camera := table.camera
	var start := camera.target
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	camera._unhandled_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(500.0, 400.0)
	drag.relative = Vector2(-60.0, 0.0)
	camera._unhandled_input(drag)
	assert_gt(camera.target.x, start.x, "dragging left moves the view east")
	for i: int in 200:
		camera._unhandled_input(drag)
	var limit := MapArt.number("camera", "min_distance", 24.0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(640.0, 400.0)
	for i: int in 60:
		camera._unhandled_input(wheel)
	for i: int in 300:
		camera._process(1.0 / 60.0)
	assert_almost_eq(camera.distance, limit, 0.01, "zoom stops at the near limit")
	var realm := Rect2(Vector2(start.x, start.y), Vector2.ZERO)
	for id: String in _map.provinces:
		var centre := table.world_position(id)
		realm = realm.expand(Vector2(centre.x, centre.z))
	assert_true(realm.grow(15.0).has_point(camera.target), "the view stays over the realm")


func _click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	return event


func _table(resolution: Vector2i) -> MapTable:
	var viewport := SubViewport.new()
	viewport.size = resolution
	viewport.own_world_3d = true
	add_child_autofree(viewport)
	var table := MapTable.new()
	viewport.add_child(table)
	table.build(_map)
	return table


func _assert_no_overlap(cells: Dictionary[String, PackedVector2Array], tolerance: float) -> void:
	var ids: Array[String] = []
	ids.assign(cells.keys())
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var shared := 0.0
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(
				cells[ids[i]], cells[ids[j]]
			):
				shared += MapGeometry.area(piece)
			assert_lt(shared, tolerance, "%s and %s overlap" % [ids[i], ids[j]])
