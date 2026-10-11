class_name BattleTargeting
extends RefCounted
## Target queries over companies. Range-limited queries go through the company grid.


## Nearest active enemy within max_range whose bearing is inside the company's facing cone.
static func in_cone(
	state: BattleState, grid: BattleGrid, company: int, half_angle: float, max_range: float
) -> int:
	var best := -1
	var best_dist := INF
	var from := state.pos[company]
	for e: int in _candidates(state, grid, from, max_range):
		if not _is_enemy_target(state, company, e):
			continue
		var dist := from.distance_to(state.pos[e])
		if dist > max_range or dist >= best_dist:
			continue
		if in_aim(state, company, state.pos[e], half_angle):
			best = e
			best_dist = dist
	return best


static func nearest(state: BattleState, company: int) -> int:
	var best := -1
	var best_dist := INF
	for e: int in state.company_count():
		if _is_enemy_target(state, company, e):
			var dist := state.pos[company].distance_to(state.pos[e])
			if dist < best_dist:
				best = e
				best_dist = dist
	return best


## Enemy company of side whose body covers point (within pick_radius of its edge).
static func at_point(
	state: BattleState, grid: BattleGrid, of_side: int, point: Vector2, pick_radius: float
) -> int:
	var best := -1
	var best_gap := INF
	for e: int in grid.query(point, pick_radius * 4.0):
		if state.side[e] == of_side or not state.is_present(e):
			continue
		var gap := point.distance_to(state.pos[e]) - state.radius[e]
		if gap <= pick_radius and gap < best_gap:
			best = e
			best_gap = gap
	return best


static func in_aim(state: BattleState, company: int, point: Vector2, half_angle: float) -> bool:
	var bearing := (point - state.pos[company]).angle()
	return absf(wrapf(bearing - state.facing[company], -PI, PI)) <= half_angle


static func is_valid_target(state: BattleState, company: int, target: int) -> bool:
	return target >= 0 and state.side[target] != state.side[company] and state.is_present(target)


static func _is_enemy_target(state: BattleState, company: int, e: int) -> bool:
	return state.side[e] != state.side[company] and state.status[e] == BattleState.Status.ACTIVE


static func _candidates(
	state: BattleState, grid: BattleGrid, from: Vector2, max_range: float
) -> PackedInt32Array:
	if is_inf(max_range):
		return PackedInt32Array(range(state.company_count()))
	return grid.query(from, max_range)
