class_name BattleMelee
extends RefCounted
## Melee between companies in contact: per-second damage, cavalry charge impacts and the
## morale shock of attacks into the flank or rear.


static func update(
	state: BattleState, rules: BattleRules, damage: PackedFloat64Array, dt: float
) -> void:
	var gap_ticks := rules.tick_rate
	for c: int in state.company_count():
		var t := state.contact[c]
		if t < 0 or state.status[c] != BattleState.Status.ACTIVE:
			continue
		var target_rule := rules.formation(state.group[t], state.formation[t])
		var from_cavalry := state.group[c] == BattleState.Group.CAVALRY
		var cavalry_factor := target_rule.cavalry_damage_taken if from_cavalry else 1.0
		if state.tick - state.last_contact_tick[c] > gap_ticks:
			_engage(state, rules, c, t, target_rule)
		state.last_contact_tick[c] = state.tick
		if state.order[c] == BattleState.Order.CAV_CHARGE:
			damage[t] += _impact(state, rules, c, t) * cavalry_factor
		var per_second := BattleDamage.melee(
			state.stats[c],
			state.stats[t].armor,
			state.group[t] == BattleState.Group.CAVALRY,
			state.speed[c]
		)
		damage[t] += per_second * cavalry_factor * dt


## A company entering melee from outside the target's front arc shocks it once.
static func _engage(
	state: BattleState,
	rules: BattleRules,
	c: int,
	t: int,
	target_rule: BattleRules.FormationRules
) -> void:
	var front := target_rule.front_half_angle
	if BattleDamage.is_flank(state.pos[c], state.pos[t], state.facing[t], front):
		state.shock[t] += rules.flank_morale


static func _impact(state: BattleState, rules: BattleRules, c: int, t: int) -> float:
	var rule := rules.formation(state.group[c], state.formation[c])
	var hit := BattleDamage.impact(
		state.stats[c],
		state.stats[t].armor,
		state.speed[c],
		state.charge_run[c],
		rule.impact,
		rules
	)
	state.order[c] = BattleState.Order.HOLD
	state.order_point[c] = state.pos[c]
	state.order_target[c] = t
	state.speed[c] = 0.0
	state.events.append(BattleEvent.new(BattleEvent.Kind.IMPACT, state.side[c], c, t))
	return hit
