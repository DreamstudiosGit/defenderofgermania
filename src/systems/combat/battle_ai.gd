class_name BattleAI
extends RefCounted
## Computer player for one side of the real-time battle. Like a human it commands one group at
## a time through a BattleInput: infantry advances and forms the hedgehog against cavalry,
## archers keep their distance, cavalry charges what it counters; the leader rallies.

const DECISION_TICKS := 12
const DECISION_JITTER := 8
const STEP := 25.0
const INFANTRY_CHARGE_RANGE := 35.0
const HEDGEHOG_ALARM := 22.0
const HEDGEHOG_CLEAR := 40.0
const ARCHER_DANGER := 25.0
const CAVALRY_MIN_RUN := 30.0
const CAVALRY_MAX_RUN := 90.0
const CAVALRY_STANDOFF := 50.0
const CAVALRY_RETREAT := 40.0
const COUNTER_BONUS := 40.0
const HEDGEHOG_PENALTY := 80.0
const LEADER_BONUS := 15.0

var side: int

var _rng := RandomNumberGenerator.new()
var _next_tick: int = 0
var _cursor: int = -1


func _init(battle_side: int, seed_value: int) -> void:
	side = battle_side
	_rng.seed = seed_value


func think(state: BattleState, rules: BattleRules) -> BattleInput:
	var input := BattleInput.new()
	if state.phase == BattleState.Phase.OVER or state.tick < _next_tick:
		return input
	_next_tick = state.tick + DECISION_TICKS + _rng.randi_range(0, DECISION_JITTER)
	if state.phase == BattleState.Phase.DEPLOY:
		_prepare(state, input)
		return input
	if _wants_rally(state, rules):
		input.rally = true
		return input
	var usable := BattleOrders.usable_groups(state, side)
	if usable.is_empty():
		return input
	_cursor = (_cursor + 1) % usable.size()
	var g := usable[_cursor]
	input.group_slot = state.side_groups[side].find(g)
	var members := state.active_members(side, g)
	match g:
		BattleState.Group.ARCHERS:
			_archers(state, rules, members, input)
		BattleState.Group.CAVALRY:
			_cavalry(state, rules, members, input)
		BattleState.Group.SIEGE:
			_siege(state, rules, members, input)
		_:
			_infantry(state, rules, members, input)
	return input


## Archers fight in the staggered formation, which fires on its own.
func _prepare(state: BattleState, input: BattleInput) -> void:
	var archers := state.active_members(side, BattleState.Group.ARCHERS)
	if not archers.is_empty() and state.formation[archers[0]] == 0:
		input.group_slot = state.side_groups[side].find(BattleState.Group.ARCHERS)
		input.formation = true


func _infantry(
	state: BattleState, rules: BattleRules, members: PackedInt32Array, input: BattleInput
) -> void:
	var center := _centroid(state, members)
	var first := members[0]
	var hedgehog := rules.formation(state.group[first], state.formation[first]).speed <= 0.0
	var cavalry := _nearest_distance(state, center, BattleState.Group.CAVALRY)
	var wants_hedgehog := cavalry < (HEDGEHOG_CLEAR if hedgehog else HEDGEHOG_ALARM)
	if wants_hedgehog != hedgehog:
		input.formation = true
		return
	if hedgehog or _busy(state, members, BattleState.Order.CHARGE):
		return
	var target := _best_target(state, rules, center, _preferred(state, members), false)
	if target < 0:
		return
	var dist := center.distance_to(state.pos[target])
	if dist <= INFANTRY_CHARGE_RANGE:
		_command(input, state.pos[target])
	else:
		var step := minf(STEP, dist - INFANTRY_CHARGE_RANGE + 5.0)
		_command(input, center + center.direction_to(state.pos[target]) * step)


func _archers(
	state: BattleState, rules: BattleRules, members: PackedInt32Array, input: BattleInput
) -> void:
	if state.formation[members[0]] == 0:
		input.formation = true
		return
	var center := _centroid(state, members)
	var threat := _nearest_melee(state, center)
	if threat >= 0 and center.distance_to(state.pos[threat]) < ARCHER_DANGER:
		_command(input, center + state.pos[threat].direction_to(center) * STEP)
		return
	var target := _best_target(state, rules, center, _preferred(state, members), false)
	if target < 0:
		return
	var reach := state.stats[members[0]].attack_range
	var dist := center.distance_to(state.pos[target])
	if dist <= reach * 0.95:
		if not _busy(state, members, BattleState.Order.FIRE):
			_command(input, state.pos[target])
	else:
		var step := minf(STEP, dist - reach * 0.85)
		_command(input, center + center.direction_to(state.pos[target]) * step)


func _cavalry(
	state: BattleState, rules: BattleRules, members: PackedInt32Array, input: BattleInput
) -> void:
	if _busy(state, members, BattleState.Order.CAV_CHARGE):
		return
	var center := _centroid(state, members)
	var engaged := false
	for c: int in members:
		var foe := state.contact[c]
		if foe < 0:
			continue
		engaged = true
		if state.stats[foe].melee_vs_cavalry > 1.0 or state.hp[c] < state.max_hp[c] * 0.5:
			var home := Vector2.LEFT if side == 0 else Vector2.RIGHT
			_command(input, center + home * CAVALRY_RETREAT)
			return
	if engaged:
		return
	var target := _best_target(state, rules, center, _preferred(state, members), true)
	if target < 0:
		return
	var at := state.pos[target]
	var dist := center.distance_to(at)
	if dist >= CAVALRY_MIN_RUN and dist <= CAVALRY_MAX_RUN:
		_command(input, at)
	else:
		_command(input, at + at.direction_to(center) * CAVALRY_STANDOFF)


## Engines stay deployed and throw at the enemy company with the most standing figures in
## range, aiming where it stands now.
func _siege(
	state: BattleState, rules: BattleRules, members: PackedInt32Array, input: BattleInput
) -> void:
	var first := members[0]
	if not rules.formation(state.group[first], state.formation[first]).can_fire:
		input.formation = true
		return
	var center := _centroid(state, members)
	var reach := state.stats[first].attack_range
	var best := -1
	var best_figures := 0
	for e: int in state.company_count():
		if state.side[e] == side or state.status[e] != BattleState.Status.ACTIVE:
			continue
		if center.distance_to(state.pos[e]) > reach:
			continue
		var figures := state.alive_figures(e)
		if figures > best_figures:
			best = e
			best_figures = figures
	if best < 0:
		return
	_command(input, state.pos[best])
	input.attack = true


func _wants_rally(state: BattleState, rules: BattleRules) -> bool:
	var leader := state.leader[side]
	if leader < 0 or state.status[leader] != BattleState.Status.ACTIVE:
		return false
	if state.rally_cooldown[side] > 0.0:
		return false
	for c: int in state.company_count():
		if state.side[c] == side and state.status[c] == BattleState.Status.FLEEING:
			if state.pos[c].distance_to(state.pos[leader]) <= rules.rally_radius:
				return true
	return false


## Nearest enemy by distance, pulled closer by counters and the leader, pushed away for
## cavalry by hedgehogs and anti-cavalry units.
func _best_target(
	state: BattleState,
	rules: BattleRules,
	from: Vector2,
	preferred: PackedStringArray,
	for_cavalry: bool
) -> int:
	var best := -1
	var best_score := INF
	for e: int in state.company_count():
		if state.side[e] == side or state.status[e] != BattleState.Status.ACTIVE:
			continue
		var score := from.distance_to(state.pos[e])
		if state.unit_ids[e] in preferred:
			score -= COUNTER_BONUS
		if state.is_leader(e):
			score -= LEADER_BONUS
		if for_cavalry:
			if rules.formation(state.group[e], state.formation[e]).cavalry_damage_taken < 1.0:
				score += HEDGEHOG_PENALTY
			if state.stats[e].melee_vs_cavalry > 1.0:
				score += COUNTER_BONUS
		if score < best_score:
			best = e
			best_score = score
	return best


func _preferred(state: BattleState, members: PackedInt32Array) -> PackedStringArray:
	var result := PackedStringArray()
	for c: int in members:
		for id: String in state.stats[c].strong_against:
			if id not in result:
				result.append(id)
	return result


func _nearest_distance(state: BattleState, from: Vector2, of_group: int) -> float:
	var best := INF
	for e: int in state.company_count():
		if state.side[e] != side and state.group[e] == of_group:
			if state.status[e] == BattleState.Status.ACTIVE:
				best = minf(best, from.distance_to(state.pos[e]))
	return best


func _nearest_melee(state: BattleState, from: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for e: int in state.company_count():
		if state.side[e] == side or state.status[e] != BattleState.Status.ACTIVE:
			continue
		if state.group[e] == BattleState.Group.ARCHERS:
			continue
		var dist := from.distance_to(state.pos[e])
		if dist < best_dist:
			best = e
			best_dist = dist
	return best


func _busy(state: BattleState, members: PackedInt32Array, busy_order: int) -> bool:
	for c: int in members:
		if state.order[c] == busy_order:
			return true
	return false


func _centroid(state: BattleState, members: PackedInt32Array) -> Vector2:
	var sum := Vector2.ZERO
	for c: int in members:
		sum += state.pos[c]
	return sum / maxi(1, members.size())


func _command(input: BattleInput, point: Vector2) -> void:
	input.command_point = true
	input.point = point
