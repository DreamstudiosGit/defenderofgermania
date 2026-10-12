class_name BattleOrders
extends RefCounted
## Turns one side's BattleInput into orders for its active group. Inputs are validated here:
## out-of-range values are clamped or ignored, so AI, players and replays share one path.

const STICK_DEADZONE := 0.15


static func apply(
	state: BattleState, rules: BattleRules, grid: BattleGrid, s: int, input: BattleInput
) -> void:
	if state.phase == BattleState.Phase.OVER:
		return
	var fighting := state.phase == BattleState.Phase.FIGHT
	_switch_group(state, s, input.group_step, input.group_slot)
	var g := state.active_group[s]
	if input.formation:
		_toggle_formation(state, rules, s, g)
	if fighting and input.rally:
		BattleMorale.rally(state, rules, s)
	var members := state.active_members(s, g)
	if g == BattleState.Group.SIEGE and _siege(state, rules, s, members, input, fighting):
		return
	if input.command_point and input.point.is_finite():
		var point := input.point.clamp(Vector2.ZERO, rules.field_size)
		var target := -1
		if fighting:
			target = BattleTargeting.at_point(state, grid, s, point, rules.pick_radius)
		if target >= 0:
			_attack(state, rules, grid, members, g, target)
		else:
			_move_to(state, rules, members, point)
	elif fighting and input.attack:
		_attack(state, rules, grid, members, g, -1)
	var move := input.move.limit_length(1.0) if input.move.is_finite() else Vector2.ZERO
	var held := move.length() > STICK_DEADZONE
	if held:
		_stick(state, rules, members, move, state.stick_held[s] == 0)
	elif state.stick_held[s] != 0:
		_release_stick(state, members)
	state.stick_held[s] = 1 if held else 0


## Deployed engines aim with the stick or a right-click and throw on attack. Returns false for
## packed engines, which drive like any other company.
static func _siege(
	state: BattleState,
	rules: BattleRules,
	s: int,
	members: PackedInt32Array,
	input: BattleInput,
	fighting: bool
) -> bool:
	var engines := PackedInt32Array()
	for c: int in members:
		if rules.formation(state.group[c], state.formation[c]).can_fire:
			engines.append(c)
	if engines.is_empty():
		return false
	if input.command_point and input.point.is_finite():
		BattleSiege.aim_at(state, rules, engines, input.point)
	var move := input.move.limit_length(1.0) if input.move.is_finite() else Vector2.ZERO
	var held := move.length() > STICK_DEADZONE
	if held:
		BattleSiege.move_aim(state, rules, engines, move)
	state.stick_held[s] = 1 if held else 0
	if fighting and input.attack:
		BattleSiege.fire(state, engines)
	return true


## Group ids the side can still command, in shield order.
static func usable_groups(state: BattleState, s: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for g: int in state.side_groups[s]:
		if not state.active_members(s, g).is_empty():
			result.append(g)
	return result


static func _switch_group(state: BattleState, s: int, step: int, slot: int) -> void:
	var usable := usable_groups(state, s)
	if usable.is_empty():
		return
	var current := state.active_group[s]
	var next := current
	var groups := state.side_groups[s]
	if slot >= 0 and slot < groups.size() and groups[slot] in usable:
		next = groups[slot]
	elif step != 0:
		var index := usable.find(current)
		next = usable[posmod(index + signi(step), usable.size())] if index >= 0 else usable[0]
	if next not in usable:
		next = usable[0]
	if next != current:
		_release_stick(state, state.active_members(s, current))
		state.active_group[s] = next


static func _toggle_formation(state: BattleState, rules: BattleRules, s: int, g: int) -> void:
	var members := state.members(s, g)
	if members.is_empty():
		return
	var next := 1 - state.formation[members[0]]
	var rule := rules.formation(g, next)
	for c: int in members:
		state.formation[c] = next
		if rule.speed <= 0.0 and state.status[c] == BattleState.Status.ACTIVE:
			_hold(state, c)
	var kind := BattleEvent.Kind.HEDGEHOG if rule.shape == "hedgehog" else BattleEvent.Kind.FORMATION
	state.events.append(BattleEvent.new(kind, s, members[0]))


static func _attack(
	state: BattleState,
	rules: BattleRules,
	grid: BattleGrid,
	members: PackedInt32Array,
	g: int,
	target: int
) -> void:
	var ordered := -1
	for c: int in members:
		# The leader moves with the cavalry but stays out of its charges: an aura and a rally
		# point, not a battering ram (captured in 21 of 24 computer battles otherwise).
		var still := rules.formation(g, state.formation[c]).speed <= 0.0
		if still or state.is_leader(c) or g == BattleState.Group.SIEGE:
			continue
		var stats := state.stats[c]
		if stats.ranged > 0.0 and stats.attack_range > 0.0:
			var aim := target
			if aim < 0:
				aim = BattleTargeting.in_cone(state, grid, c, rules.aim_cone, stats.attack_range)
			if aim < 0:
				aim = BattleTargeting.nearest(state, c)
			if aim >= 0:
				state.order[c] = BattleState.Order.FIRE
				state.order_target[c] = aim
				state.fire_pending[c] = 1
			continue
		if g == BattleState.Group.CAVALRY:
			_charge_line(state, c, target)
			ordered = c
			continue
		var foe := target
		if foe < 0:
			foe = BattleTargeting.in_cone(state, grid, c, rules.attack_cone, INF)
		if foe < 0:
			foe = BattleTargeting.nearest(state, c)
		if foe >= 0:
			state.order[c] = BattleState.Order.CHARGE
			state.order_target[c] = foe
			ordered = c
	if ordered >= 0:
		state.events.append(BattleEvent.new(BattleEvent.Kind.CHARGE, state.side[ordered], ordered))


## Cavalry rides straight ahead, or straight at the picked target.
static func _charge_line(state: BattleState, c: int, target: int) -> void:
	var direction := state.facing_vector(c)
	if target >= 0 and state.pos[target] != state.pos[c]:
		direction = state.pos[c].direction_to(state.pos[target])
	state.order[c] = BattleState.Order.CAV_CHARGE
	state.order_point[c] = direction
	state.order_target[c] = target
	state.facing[c] = direction.angle()
	state.charge_run[c] = 0.0


static func _move_to(
	state: BattleState, rules: BattleRules, members: PackedInt32Array, point: Vector2
) -> void:
	var movable := PackedInt32Array()
	var centroid := Vector2.ZERO
	for c: int in members:
		if rules.formation(state.group[c], state.formation[c]).speed > 0.0:
			movable.append(c)
			centroid += state.pos[c]
	if movable.is_empty():
		return
	centroid /= movable.size()
	for c: int in movable:
		state.order[c] = BattleState.Order.MOVE
		state.order_point[c] = (point + state.pos[c] - centroid).clamp(
			Vector2.ZERO, rules.field_size
		)
		state.fire_pending[c] = 0


## A fresh push of the stick overrides every order but a running cavalry charge; a held stick
## only steers companies that are not busy attacking.
static func _stick(
	state: BattleState, rules: BattleRules, members: PackedInt32Array, move: Vector2, fresh: bool
) -> void:
	for c: int in members:
		if rules.formation(state.group[c], state.formation[c]).speed <= 0.0:
			continue
		var current := state.order[c]
		if current == BattleState.Order.CAV_CHARGE:
			continue
		var busy := current == BattleState.Order.CHARGE or current == BattleState.Order.FIRE
		if busy and not fresh:
			continue
		state.order[c] = BattleState.Order.STICK
		state.order_point[c] = move
		state.fire_pending[c] = 0


static func _release_stick(state: BattleState, members: PackedInt32Array) -> void:
	for c: int in members:
		if state.order[c] == BattleState.Order.STICK:
			_hold(state, c)


static func _hold(state: BattleState, c: int) -> void:
	state.order[c] = BattleState.Order.HOLD
	state.order_point[c] = state.pos[c]
	state.order_target[c] = -1
