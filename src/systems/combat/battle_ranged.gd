class_name BattleRanged
extends RefCounted
## Crossbow volleys. A company holds up to rules.volleys volleys (the bolt marks) and reloads
## one per reload time. Formations without auto_fire shoot only on command (one volley per
## attack); auto_fire formations shoot whenever a target is in range and in the aim cone.


static func update(
	state: BattleState,
	rules: BattleRules,
	grid: BattleGrid,
	damage: PackedFloat64Array,
	dt: float
) -> void:
	for c: int in state.company_count():
		var stats := state.stats[c]
		if stats.ranged <= 0.0 or stats.attack_range <= 0.0:
			continue
		if state.status[c] != BattleState.Status.ACTIVE:
			continue
		var rule := rules.formation(state.group[c], state.formation[c])
		_reload(state, rules, c, stats.reload * rule.reload, dt)
		state.volley_cooldown[c] = maxf(0.0, state.volley_cooldown[c] - dt)
		if state.contact[c] >= 0 or state.volley_cooldown[c] > 0.0 or state.bolts[c] < 1:
			continue
		if not rule.auto_fire and state.fire_pending[c] == 0:
			continue
		var target := _target(state, rules, grid, c, rule.auto_fire)
		if target < 0:
			continue
		damage[target] += BattleDamage.volley(stats, state.stats[target].armor, rule.volley)
		state.bolts[c] -= 1
		state.volley_cooldown[c] = rules.volley_interval
		state.fire_pending[c] = 0
		state.events.append(BattleEvent.new(BattleEvent.Kind.VOLLEY, state.side[c], c, target))


static func _reload(
	state: BattleState, rules: BattleRules, c: int, interval: float, dt: float
) -> void:
	if state.bolts[c] >= rules.volleys:
		state.reload_timer[c] = 0.0
		return
	state.reload_timer[c] += dt
	if state.reload_timer[c] >= interval:
		state.reload_timer[c] -= interval
		state.bolts[c] += 1


## The ordered target if it can be hit, else (or while auto-firing) the nearest active enemy
## in range and aim cone.
static func _target(
	state: BattleState, rules: BattleRules, grid: BattleGrid, c: int, auto_fire: bool
) -> int:
	var reach := state.stats[c].attack_range
	if state.order[c] == BattleState.Order.FIRE:
		var ordered := state.order_target[c]
		if BattleTargeting.is_valid_target(state, c, ordered):
			if state.pos[c].distance_to(state.pos[ordered]) <= reach:
				if BattleTargeting.in_aim(state, c, state.pos[ordered], rules.aim_cone):
					return ordered
			if not auto_fire:
				return -1
	return BattleTargeting.in_cone(state, grid, c, rules.aim_cone, reach)
