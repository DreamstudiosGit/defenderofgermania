class_name BattleFormations
extends RefCounted
## Figure slots of a formation in company-local meters: x points forward, y to the right.
## Results are cached and shared, so callers must not modify them.

static var _cache: Dictionary[String, PackedVector2Array] = {}


static func slots(shape: String, count: int, spacing: float) -> PackedVector2Array:
	var key := "%s/%d/%.3f" % [shape, count, spacing]
	if _cache.has(key):
		return _cache[key]
	var result := PackedVector2Array()
	if count <= 1:
		result.append(Vector2.ZERO)
	else:
		match shape:
			"hedgehog":
				result = _ring(count, spacing)
			"staggered":
				result = _ranks(count, 3, spacing, true)
			"wedge":
				result = _wedge(count, spacing)
			_:
				result = _ranks(count, 2, spacing, false)
	_cache[key] = result
	return result


## Distance from the company center to its outermost figure's edge.
static func radius(company_slots: PackedVector2Array, figure_radius: float) -> float:
	var reach := 0.0
	for slot: Vector2 in company_slots:
		reach = maxf(reach, slot.length())
	return reach + figure_radius


static func _ranks(count: int, ranks: int, spacing: float, stagger: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	var cols := ceili(count / float(ranks))
	var used_ranks := ceili(count / float(cols))
	for i: int in count:
		@warning_ignore("integer_division")
		var rank := i / cols
		var col := i % cols
		var in_rank := mini(cols, count - rank * cols)
		var y := (col - (in_rank - 1) * 0.5) * spacing
		if stagger and rank % 2 == 1:
			y += spacing * 0.5
		var x := ((used_ranks - 1) * 0.5 - rank) * spacing
		result.append(Vector2(x, y))
	return result


static func _ring(count: int, spacing: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var ring_radius := maxf(spacing, count * spacing / TAU)
	for i: int in count:
		result.append(Vector2.from_angle(TAU * i / count) * ring_radius)
	return result


static func _wedge(count: int, spacing: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	var row := 0
	while result.size() < count:
		for j: int in row + 1:
			if result.size() == count:
				break
			result.append(Vector2(-row * spacing * 0.9, (j - row * 0.5) * spacing))
		row += 1
	var mean_x := 0.0
	for slot: Vector2 in result:
		mean_x += slot.x
	mean_x /= count
	for i: int in count:
		result[i] = result[i] - Vector2(mean_x, 0.0)
	return result
