class_name RaidWorld
extends Node3D
## The castle interior as a cut-away side view along the raid layout, built from primitives:
## floors with stairs between the guard posts, masonry back walls, ceilings, a cellar or a gallery
## for each sneak path and the closed ends. Heights are presentation only; the simulation runs on
## one line (RaidLayout x).

## Depth lanes: fighters walk at LANE_Z; cellars run in front of it, galleries behind it.
const LANE_Z := 0.0
const CELLAR_Z := 0.85
const GALLERY_Z := -1.45
const OPENING_Z := 0.4
const STEPS := 6
const END_WALL := 6.0

var layout: RaidLayout
var floor_depth: float
var back_z: float
var front_z: float
## Stairs as (start x, end x, rise).
var stairs: Array[Vector3] = []
## Flat stretches as (start x, end x, floor level); stretch i lies before stair i.
var stretches: Array[Vector3] = []
## Ceiling height above the floor of each stretch.
var ceilings := PackedFloat64Array()

var _masonry := RaidMasonry.new()
var _paths: Array[PackedVector3Array] = []


func build(raid_layout: RaidLayout, seed_value: int) -> void:
	layout = raid_layout
	floor_depth = RaidArt.number("rooms", "floor_depth", 1.0)
	back_z = RaidArt.number("rooms", "back_z", -2.4)
	front_z = RaidArt.number("rooms", "front_z", 1.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_plan_levels(rng)
	_plan_ceilings(rng)
	for i: int in stretches.size():
		_build_stretch(i)
	for i: int in stairs.size():
		_build_stair(i)
	for i: int in layout.sneak_paths.size():
		_paths.append(_build_sneak_path(layout.sneak_paths[i]))
	_build_ends()
	add_child(_masonry.build(rng))


## Floor height at corridor position x.
func floor_y(x: float) -> float:
	var level := 0.0
	for stair: Vector3 in stairs:
		if x <= stair.x:
			return level
		if x < stair.y:
			return level + stair.z * (x - stair.x) / (stair.y - stair.x)
		level += stair.z
	return level


## Where the leader is on sneak path `index` at progress 0–1.
func sneak_point(index: int, progress: float) -> Vector3:
	var points := _paths[index]
	var total := 0.0
	for i: int in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	var wanted := clampf(progress, 0.0, 1.0) * total
	for i: int in range(1, points.size()):
		var length := points[i - 1].distance_to(points[i])
		if wanted <= length and length > 0.0:
			return points[i - 1].lerp(points[i], wanted / length)
		wanted -= length
	return points[points.size() - 1]


func ceiling_at(x: float) -> float:
	for i: int in stretches.size():
		if x <= _stretch_end(i):
			return stretches[i].z + ceilings[i]
	return floor_y(x) + ceilings[ceilings.size() - 1]


func _plan_levels(rng: RandomNumberGenerator) -> void:
	var steps := RaidArt.list("rooms", "level_steps")
	var offset := RaidArt.number("rooms", "stair_offset", 5.0)
	var length := RaidArt.number("rooms", "stair_length", 2.4)
	var level := 0.0
	var start := -END_WALL
	for post: float in layout.posts:
		var rise := 0.0
		if not steps.is_empty():
			rise = float(steps[rng.randi_range(0, steps.size() - 1)])
		if level + rise > 2.4 or level + rise < -1.2:
			rise = -rise
		if is_zero_approx(rise):
			continue
		var stair_x := post + offset
		stretches.append(Vector3(start, stair_x, level))
		stairs.append(Vector3(stair_x, stair_x + length, rise))
		level += rise
		start = stair_x + length
	stretches.append(Vector3(start, layout.end_x + END_WALL, level))


func _plan_ceilings(rng: RandomNumberGenerator) -> void:
	var low := RaidArt.number("rooms", "ceiling", 4.2)
	var high := RaidArt.number("rooms", "hall_ceiling", 5.6)
	for i: int in stretches.size():
		var hall := rng.randf() < 0.4 or stretches[i].y > layout.door_x
		for path: RaidLayout.SneakPath in layout.sneak_paths:
			hall = hall or (not path.below and path.from_x >= stretches[i].x and path.to_x <= stretches[i].y)
		ceilings.append(high if hall else low)


func _stretch_end(i: int) -> float:
	return stairs[i].y if i < stairs.size() else stretches[i].y


func _build_stretch(i: int) -> void:
	var stretch := stretches[i]
	var x0 := stretch.x
	var x1 := stretch.y
	var level := stretch.z
	var top := level + ceilings[i]
	var openings := _cellar_openings(x0, x1)
	# Back strip of the floor runs through; the front strip leaves room for cellar stairs.
	_slab(x0, x1, level - floor_depth, level, back_z, OPENING_Z, "floor")
	var cursor := x0
	for opening: Vector2 in openings:
		_slab(cursor, opening.x, level - floor_depth, level, OPENING_Z, front_z, "floor")
		cursor = opening.y
	_slab(cursor, x1, level - floor_depth, level, OPENING_Z, front_z, "floor")
	_fill_below(x0, x1, level - floor_depth)
	cursor = x0
	for opening: Vector2 in openings:
		_masonry.wall(
			cursor, opening.x, level - floor_depth, level - 0.12, front_z + RaidMasonry.DEPTH
		)
		cursor = opening.y
	_masonry.wall(cursor, x1, level - floor_depth, level - 0.12, front_z + RaidMasonry.DEPTH)
	var wall_end := x1 if i >= stairs.size() else stairs[i].y
	_masonry.wall(x0, wall_end, level - floor_depth, top, back_z)
	_slab(x0, x1, level, level + 0.42, back_z, back_z + 0.16, "stone_dark")
	if i < stairs.size():
		_slab(x1 - 0.4, x1 + 0.4, level - floor_depth, top, back_z, back_z + 0.32, "stone_dark")
	_slab(x0, wall_end, top, top + 0.5, back_z, front_z - 0.6, "stone_dark")
	_slab(x0, wall_end, top + 0.5, top + 8.0, back_z, front_z, "stone_cut")
	var beam := x0 + 1.2
	while beam < wall_end - 0.5:
		add_child(RaidArt.box(
			Vector3(0.28, 0.32, front_z - back_z - 0.6),
			Vector3(beam, top - 0.16, (back_z + front_z - 0.6) * 0.5),
			"wood_dark"
		))
		beam += 2.4


func _build_stair(i: int) -> void:
	var stair := stairs[i]
	var level := stretches[i].z
	var run := (stair.y - stair.x) / STEPS
	for step: int in STEPS:
		var height := level + stair.z * float(step + 1) / STEPS
		var low := minf(height, level) - floor_depth
		_slab(
			stair.x + step * run, stair.x + (step + 1) * run, low, height, back_z, front_z, "floor"
		)
	_fill_below(stair.x, stair.y, minf(level, level + stair.z) - floor_depth)


## Box spanning x0–x1, y0–y1, z0–z1 in a palette colour.
func _slab(
	x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, color_key: String
) -> void:
	if x1 - x0 <= 0.01 or y1 - y0 <= 0.01:
		return
	var size := Vector3(x1 - x0, y1 - y0, z1 - z0)
	add_child(RaidArt.box(
		size, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), color_key
	))


## Solid masonry under the floor, except where a cellar is cut into it.
func _fill_below(x0: float, x1: float, top: float) -> void:
	var cursor := x0
	var depth := RaidArt.number("rooms", "cellar_depth", 2.7)
	for path: RaidLayout.SneakPath in layout.sneak_paths:
		if not path.below or path.to_x <= x0 or path.from_x >= x1:
			continue
		_slab(cursor, maxf(cursor, path.from_x), top - 8.0, top, back_z, front_z, "stone_cut")
		var level := floor_y(path.from_x)
		_slab(
			maxf(x0, path.from_x),
			minf(x1, path.to_x),
			top - 8.0,
			level - depth - 0.4,
			back_z,
			front_z,
			"stone_cut"
		)
		cursor = minf(x1, path.to_x)
	_slab(cursor, x1, top - 8.0, top, back_z, front_z, "stone_cut")


func _cellar_openings(x0: float, x1: float) -> Array[Vector2]:
	var length := RaidArt.number("rooms", "stair_length", 2.4)
	var openings: Array[Vector2] = []
	for path: RaidLayout.SneakPath in layout.sneak_paths:
		if path.below and path.from_x >= x0 and path.to_x <= x1:
			openings.append(Vector2(path.from_x, path.from_x + length))
			openings.append(Vector2(path.to_x - length, path.to_x))
	return openings


func _build_sneak_path(path: RaidLayout.SneakPath) -> PackedVector3Array:
	var level := floor_y(path.from_x)
	var length := RaidArt.number("rooms", "stair_length", 2.4)
	if path.below:
		var depth := RaidArt.number("rooms", "cellar_depth", 2.7)
		var bottom := level - depth
		_slab(path.from_x, path.to_x, bottom - 0.4, bottom, back_z, front_z, "stone_dark")
		_masonry.wall(path.from_x, path.to_x, bottom - 0.4, level - floor_depth, back_z)
		for end: int in 2:
			var start := path.from_x if end == 0 else path.to_x - length
			for step: int in STEPS:
				var share := float(step + 1) / STEPS if end == 1 else 1.0 - float(step) / STEPS
				var height := bottom + depth * share
				var x := start + step * length / STEPS
				_slab(x, x + length / STEPS, bottom, height, OPENING_Z, front_z, "stone")
		return PackedVector3Array([
			Vector3(path.from_x, level, LANE_Z), Vector3(path.from_x + length, bottom, CELLAR_Z),
			Vector3(path.to_x - length, bottom, CELLAR_Z), Vector3(path.to_x, level, LANE_Z)
		])
	var rise := RaidArt.number("rooms", "gallery_height", 2.9)
	var walk0 := path.from_x + 0.8 + length
	var walk1 := path.to_x - 0.8 - length
	_slab(walk0, walk1, level + rise - 0.25, level + rise, back_z + 0.1, GALLERY_Z + 0.55, "wood")
	var post := walk0
	while post <= walk1:
		_slab(
			post - 0.06,
			post + 0.06,
			level + rise,
			level + rise + 0.9,
			GALLERY_Z + 0.45,
			GALLERY_Z + 0.57,
			"wood_dark"
		)
		post += 1.2
	_slab(
		walk0,
		walk1,
		level + rise + 0.85,
		level + rise + 0.95,
		GALLERY_Z + 0.45,
		GALLERY_Z + 0.57,
		"wood_dark"
	)
	for end: int in 2:
		var start := path.from_x + 0.8 if end == 0 else walk1
		for step: int in STEPS:
			var share := float(step + 1) / STEPS if end == 0 else 1.0 - float(step) / STEPS
			var x := start + step * length / STEPS
			_slab(
				x,
				x + length / STEPS,
				level,
				level + rise * share,
				GALLERY_Z - 0.5,
				GALLERY_Z + 0.5,
				"wood"
			)
	return PackedVector3Array([
		Vector3(path.from_x, level, LANE_Z), Vector3(path.from_x + 0.8, level, GALLERY_Z),
		Vector3(walk0, level + rise, GALLERY_Z), Vector3(walk1, level + rise, GALLERY_Z),
		Vector3(path.to_x - 0.8, level, GALLERY_Z), Vector3(path.to_x, level, LANE_Z)
	])


func _build_ends() -> void:
	var start_level := floor_y(0.0)
	var end_level := floor_y(layout.end_x)
	_slab(
		-END_WALL - 4.0, -1.2, start_level - 8.0, start_level + 12.0, back_z, front_z, "stone_cut"
	)
	_masonry.wall(
		-END_WALL - 4.0, -1.2, start_level - 4.0, start_level + 8.0, front_z + RaidMasonry.DEPTH
	)
	_masonry.wall(
		layout.end_x + 0.4,
		layout.end_x + END_WALL + 4.0,
		end_level - 4.0,
		end_level + 8.0,
		front_z + RaidMasonry.DEPTH
	)
	_slab(
		layout.end_x + 0.4,
		layout.end_x + END_WALL + 4.0,
		end_level - 8.0,
		end_level + 12.0,
		back_z,
		front_z,
		"stone_cut"
	)
