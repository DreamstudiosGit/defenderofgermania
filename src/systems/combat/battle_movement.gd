class_name BattleMovement
extends RefCounted
## Moves company centers by their orders: speed with acceleration, limited turning, stopping
## on melee contact, flight to the own edge, keeping friendly companies and obstacles apart.

const ARRIVE_DISTANCE := 0.75
const HOLD_SLACK := 1.0
const SEPARATION_RATE := 0.25
const EDGE := 0.5


static func update(state: BattleState, rules: BattleRules, grid: BattleGrid, dt: float) -> void:
	for c: int in state.company_count():
		if state.is_present(c):
			state.radius[c] = BattleFormations.radius(
				BattleDeployment.company_slots(state, rules, c),
				BattleDeployment.figure_radius(state, rules, c)
			)
	for c: int in state.company_count():
		if state.is_present(c):
			_move(state, rules, c, dt)
	_separate(state, rules, grid)


static func _move(state: BattleState, rules: BattleRules, c: int, dt: float) -> void:
	var stats := state.stats[c]
	var rule := rules.formation(state.group[c], state.formation[c])
	var at := state.pos[c]
	var direction := Vector2.ZERO
	var desired := 0.0
	var look := NAN
	var foe := state.contact[c]
	var fleeing := state.status[c] == BattleState.Status.FLEEING
	if fleeing:
		direction = Vector2.LEFT if state.side[c] == 0 else Vector2.RIGHT
		desired = stats.speed * rules.flee_speed_factor
	else:
		match state.order[c]:
			BattleState.Order.HOLD:
				var gap := at.distance_to(state.order_point[c])
				if gap > HOLD_SLACK:
					direction = at.direction_to(state.order_point[c])
					desired = stats.speed * rule.speed * minf(1.0, gap / 2.0)
			BattleState.Order.MOVE:
				if at.distance_to(state.order_point[c]) <= ARRIVE_DISTANCE:
					_hold(state, c)
				else:
					direction = at.direction_to(state.order_point[c])
					desired = stats.speed * rule.speed
			BattleState.Order.STICK:
				direction = state.order_point[c].normalized()
				desired = stats.speed * rule.speed * state.order_point[c].length()
			BattleState.Order.CHARGE:
				var target := state.order_target[c]
				if state.status[target] != BattleState.Status.ACTIVE:
					_hold(state, c)
				else:
					direction = at.direction_to(state.pos[target])
					desired = stats.speed * rule.speed
			BattleState.Order.CAV_CHARGE:
				direction = state.order_point[c]
				desired = stats.charge_speed
				look = direction.angle()
				state.charge_run[c] += state.speed[c] * dt
				if state.charge_run[c] >= rules.charge_max_distance:
					_hold(state, c)
			BattleState.Order.FIRE:
				var target := state.order_target[c]
				if not BattleTargeting.is_valid_target(state, c, target):
					_hold(state, c)
				else:
					look = (state.pos[target] - at).angle()
					if at.distance_to(state.pos[target]) > stats.attack_range:
						direction = at.direction_to(state.pos[target])
						desired = stats.speed * rule.speed
	if foe >= 0 and not fleeing:
		look = (state.pos[foe] - at).angle()
		if state.order[c] != BattleState.Order.STICK or direction.dot(state.pos[foe] - at) > 0.0:
			desired = 0.0
			state.speed[c] = 0.0
	if is_nan(look) and direction != Vector2.ZERO and desired > 0.0:
		look = direction.angle()
	if not is_nan(look):
		state.facing[c] = _turn(state.facing[c], look, rules.turn_rate * dt)
	state.speed[c] = move_toward(state.speed[c], desired, rules.acceleration * dt)
	state.pos[c] = _bounded(state, rules, c, at + direction * state.speed[c] * dt)
	if fleeing and _at_own_edge(state, rules, c):
		state.status[c] = BattleState.Status.FLED
		state.contact[c] = -1


static func _turn(from: float, to: float, max_step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	return wrapf(from + clampf(diff, -max_step, max_step), -PI, PI)


static func _bounded(state: BattleState, rules: BattleRules, c: int, at: Vector2) -> Vector2:
	var low := Vector2.ZERO
	var high := rules.field_size
	if state.phase == BattleState.Phase.DEPLOY:
		if state.side[c] == 0:
			high.x = rules.deploy_depth
		else:
			low.x = rules.field_size.x - rules.deploy_depth
	return _outside_obstacles(rules, at, state.radius[c] * 0.5).clamp(low, high)


static func _outside_obstacles(rules: BattleRules, at: Vector2, body: float) -> Vector2:
	var result := at
	for obstacle: Vector3 in rules.obstacles:
		var center := Vector2(obstacle.x, obstacle.y)
		var keep := obstacle.z + body
		var dist := result.distance_to(center)
		if dist < keep:
			var away := Vector2.RIGHT if dist <= 0.0 else center.direction_to(result)
			result = center + away * keep
	return result


static func _at_own_edge(state: BattleState, rules: BattleRules, c: int) -> bool:
	if state.side[c] == 0:
		return state.pos[c].x <= EDGE
	return state.pos[c].x >= rules.field_size.x - EDGE


static func _separate(state: BattleState, rules: BattleRules, grid: BattleGrid) -> void:
	var include := PackedByteArray()
	include.resize(state.company_count())
	for c: int in state.company_count():
		include[c] = 1 if state.is_present(c) else 0
	grid.rebuild(state.pos, include)
	var widest := 0.0
	for c: int in state.company_count():
		if include[c] != 0:
			widest = maxf(widest, state.radius[c])
	for c: int in state.company_count():
		if include[c] == 0:
			continue
		for o: int in grid.query(state.pos[c], state.radius[c] + widest):
			if o <= c or state.side[o] != state.side[c]:
				continue
			var offset := state.pos[o] - state.pos[c]
			var overlap := state.radius[c] + state.radius[o] - offset.length()
			if overlap <= 0.0:
				continue
			var away := Vector2.DOWN if offset == Vector2.ZERO else offset.normalized()
			var push := away * overlap * SEPARATION_RATE
			_shift(state, rules, c, -push)
			_shift(state, rules, o, push)


## Pushed companies that hold accept their new spot instead of fighting back to the old one.
static func _shift(state: BattleState, rules: BattleRules, c: int, push: Vector2) -> void:
	state.pos[c] = _bounded(state, rules, c, state.pos[c] + push)
	if state.order[c] == BattleState.Order.HOLD:
		state.order_point[c] = state.pos[c]


static func _hold(state: BattleState, c: int) -> void:
	state.order[c] = BattleState.Order.HOLD
	state.order_point[c] = state.pos[c]
	state.order_target[c] = -1
