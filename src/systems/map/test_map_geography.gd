extends GutTest
## Province centres against the adjacency list: neighbours are close, the closest province is
## always a neighbour, no two centres crowd each other, all lie inside the realm.

const MAX_NEIGHBOR_KM := 300.0
const MIN_GAP_KM := 40.0

var _map: MapData


func before_all() -> void:
	_map = MapData.load_file()


func test_projection_maps_degrees_to_kilometres() -> void:
	var geo := _map.geography
	assert_eq(geo.to_km(geo.origin), Vector2.ZERO)
	assert_almost_eq(geo.to_km(geo.origin + Vector2(0, 1)).y, -MapGeography.KM_PER_DEGREE_LAT, 1e-6)
	var east := geo.to_km(geo.origin + Vector2(1, 0)).x
	assert_almost_eq(east, 111.32 * cos(deg_to_rad(geo.origin.y)), 1e-6)


func test_every_centre_lies_inside_the_realm() -> void:
	for province: MapData.ProvinceDef in _map.provinces.values():
		assert_true(_map.geography.contains(province.at), province.id)


func test_neighbours_lie_close_together() -> void:
	for province: MapData.ProvinceDef in _map.provinces.values():
		for other: String in province.neighbors:
			var km := _km(province.id, other)
			assert_lt(km, MAX_NEIGHBOR_KM, "%s-%s %.0f km" % [province.id, other, km])


func test_closest_province_is_always_a_neighbour() -> void:
	for province: MapData.ProvinceDef in _map.provinces.values():
		var closest := ""
		var best := INF
		for other: String in _map.provinces:
			if other != province.id and _km(province.id, other) < best:
				best = _km(province.id, other)
				closest = other
		assert_true(closest in province.neighbors, "%s: closest is %s" % [province.id, closest])
		assert_gt(best, MIN_GAP_KM, "%s crowds %s" % [province.id, closest])


func _km(a: String, b: String) -> float:
	var geo := _map.geography
	return geo.to_km(_map.provinces[a].at).distance_to(geo.to_km(_map.provinces[b].at))
