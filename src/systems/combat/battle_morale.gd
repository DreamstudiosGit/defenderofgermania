class_name BattleMorale
extends RefCounted
## Applies the tick's damage, then morale: start value, -1 per 2 % HP lost, one-off shocks and
## the leader's aura; companies below the threshold flee, the leader can rally them.


static func update(
	state: BattleState, rules: BattleRules, damage: PackedFloat64Array, dt: float
) -> void:
	_apply_damage(state, rules, damage)
	for c: int in state.company_count():
		if state.is_leader(c) or not state.is_present(c):
			continue
		state.morale[c] = value(state, rules, c)
		if state.status[c] == BattleState.Status.ACTIVE and state.morale[c] < rules.flee_below:
			state.status[c] = BattleState.Status.FLEEING
			state.order[c] = BattleState.Order.HOLD
			state.fire_pending[c] = 0
			state.events.append(BattleEvent.new(BattleEvent.Kind.ROUT, state.side[c], c))
	for s: int in BattleState.SIDES:
		state.rally_cooldown[s] = maxf(0.0, state.rally_cooldown[s] - dt)


## Current morale of a regular company.
static func value(state: BattleState, rules: BattleRules, company: int) -> float:
	return base_value(state, rules, company) + state.shock[company] + aura(state, company)


## Morale from the start value and lost health only.
static func base_value(state: BattleState, rules: BattleRules, company: int) -> float:
	var lost_percent := (1.0 - state.hp[company] / state.max_hp[company]) * 100.0
	return state.start_morale[company] - lost_percent * rules.morale_per_hp_percent


static func aura(state: BattleState, company: int) -> float:
	var s := state.side[company]
	var leader := state.leader[s]
	if leader < 0 or state.status[leader] != BattleState.Status.ACTIVE or state.aura_off[s] == 1:
		return 0.0
	var stats := state.stats[leader]
	if state.pos[company].distance_to(state.pos[leader]) <= stats.aura_radius:
		return stats.aura_morale
	return 0.0


## Brings fleeing companies near the leader back with at least rally_morale; returns how many.
## The cooldown only starts when someone was rallied.
static func rally(state: BattleState, rules: BattleRules, s: int) -> int:
	var leader := state.leader[s]
	if leader < 0 or state.status[leader] != BattleState.Status.ACTIVE:
		return 0
	if state.rally_cooldown[s] > 0.0:
		return 0
	var rallied := 0
	for c: int in state.company_count():
		if state.side[c] != s or state.status[c] != BattleState.Status.FLEEING:
			continue
		if state.pos[c].distance_to(state.pos[leader]) > rules.rally_radius:
			continue
		state.status[c] = BattleState.Status.ACTIVE
		state.order[c] = BattleState.Order.HOLD
		state.order_point[c] = state.pos[c]
		state.shock[c] = maxf(state.shock[c], rules.rally_morale - base_value(state, rules, c))
		state.morale[c] = value(state, rules, c)
		rallied += 1
	if rallied > 0:
		state.rally_cooldown[s] = rules.rally_cooldown
		state.events.append(BattleEvent.new(BattleEvent.Kind.RALLY, s, leader))
	return rallied


static func _apply_damage(
	state: BattleState, rules: BattleRules, damage: PackedFloat64Array
) -> void:
	for c: int in state.company_count():
		if damage[c] <= 0.0 or not state.is_present(c):
			continue
		state.hp[c] = maxf(0.0, state.hp[c] - damage[c])
		if state.hp[c] > 0.0:
			continue
		state.order[c] = BattleState.Order.HOLD
		state.contact[c] = -1
		if not state.is_leader(c):
			state.status[c] = BattleState.Status.DESTROYED
			continue
		state.status[c] = BattleState.Status.CAPTURED
		var s := state.side[c]
		state.events.append(BattleEvent.new(BattleEvent.Kind.LEADER_CAPTURED, s, c))
		for o: int in state.company_count():
			if state.side[o] == s and state.is_present(o) and not state.is_leader(o):
				state.shock[o] += rules.leader_captured_morale
