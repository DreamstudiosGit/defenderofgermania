class_name BattleScenery
extends Node3D

const TREES: Array[String] = ["tree_oak", "tree_birch", "tree_pine", "tree_oak"]

var _placements: Dictionary[String, Array] = {}
var _trees: Array[String] = TREES.duplicate()
var _tree_positions: Array[Vector3] = []


func build(rules: BattleRules, style: Dictionary = {}) -> void:
	var settings: Dictionary = BattleModels.settings().get("scenery", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings.get("seed", 1198))
	if style.get("tree_palette", "summer") == "autumn":
		_trees = ["tree_oak_autumn", "tree_birch", "tree_pine", "tree_oak_autumn"]
	var size := rules.field_size
	var groves: Array = settings.get("groves", [])
	for entry: Array in groves:
		var center := Vector3(float(entry[0]) * size.x, 0, float(entry[1]) * size.y)
		var count := int(float(entry[4]) * float(style.get("tree_density", 1.0)))
		_grove(center, Vector2(entry[2], entry[3]), count, settings, size, rng)
	_ground_cover(rules, settings, rng)
	_add_river(size, settings, rng)
	_add_camps(size)
	_add_obstacles(rules, rng)
	for filename: String in _placements:
		_add_batch(filename, _placements[filename])


func _grove(
	center: Vector3, extent: Vector2, count: int, settings: Dictionary,
	size: Vector2, rng: RandomNumberGenerator
) -> void:
	var spacing := float(settings.get("grove_spacing", 2.7))
	var low := float(settings.get("tree_scale_min", 0.85))
	var high := float(settings.get("tree_scale_max", 1.4))
	for attempt: int in count * 5:
		if count <= 0:
			break
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf())
		var at := center + Vector3(cos(angle) * extent.x, 0, sin(angle) * extent.y) * radius
		if at.x > -2 and at.x < size.x + 2 and at.z > -2 and at.z < size.y + 2:
			continue
		var crowded := false
		for other: Vector3 in _tree_positions:
			if at.distance_squared_to(other) < spacing * spacing:
				crowded = true
				break
		if crowded:
			continue
		_tree_positions.append(at)
		count -= 1
		var kind := _trees[rng.randi_range(0, _trees.size() - 1)]
		_place(kind, at, rng.randf_range(low, high), rng.randf() * TAU)
		for i: int in 3:
			var under := at + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
			_place("foliage_bush" if i == 0 else "foliage_fern", under,
				rng.randf_range(0.7, 1.4), rng.randf() * TAU)
		if rng.randf() < 0.20:
			_place("rock_cluster", at + Vector3(1.5, 0, 0.5), rng.randf_range(0.5, 0.9))
		if rng.randf() < 0.06:
			_place("foliage_stump", at + Vector3(-1, 0, 1), 0.8)


func _ground_cover(rules: BattleRules, settings: Dictionary, rng: RandomNumberGenerator) -> void:
	var size := rules.field_size
	var count := int(float(settings.get("ground_foliage_density", 0.16)) * size.x * size.y)
	for i: int in count:
		var at := Vector3(rng.randf_range(-4, size.x + 4), 0, rng.randf_range(-3, size.y + 5))
		var lane := absf(at.z - size.y * 0.45 - sin(at.x * 0.10) * 1.8)
		var edge := minf(minf(at.x, size.x - at.x), minf(at.z, size.y - at.z))
		if lane < 3.0 and rng.randf() < 0.9:
			_place("terrain_pebble_patch", at + Vector3(0, 0.007, 0), rng.randf_range(0.8, 1.2))
			continue
		var kind := "foliage_grass" if i % 4 != 0 else "foliage_flowers"
		_place(kind, at, rng.randf_range(0.75, 1.2), rng.randf() * TAU)
		if edge < 1.0 and i % 5 == 0:
			_place("foliage_bush", at, rng.randf_range(0.65, 1.2), rng.randf() * TAU)
		if edge < 0.0 and i % 9 == 0:
			_place("rock_small", at, rng.randf_range(0.45, 0.9), rng.randf() * TAU)


func _add_river(size: Vector2, settings: Dictionary, rng: RandomNumberGenerator) -> void:
	var river := BattleRiver.new()
	add_child(river)
	river.build(size, settings)
	var width := float(settings.get("river_width", 5.4))
	for x: float in _steps(-18, size.x + 18, 2.2):
		var center := river.center_at(x)
		for side: float in [-1, 1]:
			var bank := center + Vector3(0, 0, side * (width * 0.5 + rng.randf_range(0.1, 0.6)))
			_place("rock_small", bank, rng.randf_range(0.7, 1.5), rng.randf() * TAU)
			if int(x) % 3 == 0:
				_place("foliage_reeds", bank + Vector3(0, 0, side * 0.5), 0.9)
			if x < size.x * 0.43 or x > size.x * 0.57:
				_place("foliage_flowers", bank + Vector3(0, 0, side * 1.5), 1.15)
		if int(x) % 7 == 0:
			_place("foliage_water_lilies", center + Vector3(0, 0.04, width * 0.27), 0.8)
	var crossing := river.center_at(size.x * 0.5)
	_place("prop_bridge_wood", crossing, 1.1)
	_place("terrain_path", crossing + Vector3(0, 0.008, 7.5), 1, 0, Vector3(4.5, 1, 8))
	_place("terrain_path", crossing + Vector3(0, 0.008, -7.5), 1, 0, Vector3(4.5, 1, 8))


func _add_camps(size: Vector2) -> void:
	var teams: Array = BattleModels.settings().get("teams", [])
	for side: int in teams.size():
		var team := str(teams[side])
		var x := -5.0 if side == 0 else size.x + 5.0
		var facing := PI / 2 if side == 0 else -PI / 2
		_place("prop_banner_" + team, Vector3(x, 0, size.y * 0.30), 1.1, facing)
		_place("prop_tent_" + team, Vector3(x + (-2 if side == 0 else 2), 0, size.y * 0.38), 1, facing)
		_place("prop_barrel_wood", Vector3(x, 0, size.y * 0.40), 1)
		_place("prop_watchtower_" + team, Vector3(size.x * (0.16 + side * 0.68), 0, -4), 0.85)
		for i: int in 3:
			_place("prop_fence_wood", Vector3(x, 0, size.y * 0.48 + i * 3), 1, PI / 2)


func _add_obstacles(rules: BattleRules, rng: RandomNumberGenerator) -> void:
	for i: int in rules.obstacles.size():
		var obstacle := rules.obstacles[i]
		var kind := _trees[i % _trees.size()] if rules.obstacle_kinds[i] == "tree" else "rock_boulder"
		var asset := BattleModels.mesh(kind)
		if asset == null:
			continue
		var bounds := asset.get_aabb()
		var radius := maxf(bounds.size.x, bounds.size.z) * 0.5
		var center := Vector3(obstacle.x, 0, obstacle.y)
		_place(kind, center, obstacle.z / radius, i * 0.7)
		for j: int in 7:
			var angle := j * TAU / 7
			var at := center + Vector3(cos(angle), 0, sin(angle)) * obstacle.z * 0.7
			_place("foliage_bush" if j % 3 == 0 else "foliage_flowers", at,
				rng.randf_range(0.65, 1.2), angle)


func _place(
	filename: String, at: Vector3, scale_factor: float, angle: float = 0,
	stretch: Vector3 = Vector3.ONE
) -> void:
	if not _placements.has(filename):
		_placements[filename] = []
	_placements[filename].append(
		Transform3D(Basis(Vector3.UP, angle).scaled(stretch * scale_factor), at)
	)


func _add_batch(filename: String, placements: Array) -> void:
	var mesh := BattleModels.mesh(filename)
	if mesh == null:
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = placements.size()
	for i: int in placements.size():
		multimesh.set_instance_transform(i, placements[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = filename
	instance.multimesh = multimesh
	add_child(instance)


static func _steps(start: float, end: float, step: float) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	var cursor := start
	while cursor <= end:
		values.append(cursor)
		cursor += step
	return values
