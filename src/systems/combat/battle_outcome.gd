class_name BattleOutcome
extends RefCounted
## Ends the battle and builds its BattleResult. A side loses when none of its companies still
## fights (all fled, fleeing or destroyed; a lone leader does not hold the field). At the time
## limit the higher AutoResolve strength on current health wins, without chance; ties go to
## the defender, who holds the field.


static func update(state: BattleState, cfg: CombatConfig, setup: BattleSetup) -> void:
	var attacker_out := not _has_fighters(state, 0)
	var defender_out := not _has_fighters(state, 1)
	if attacker_out or defender_out:
		_finish(state, 1 if attacker_out else 0)
		return
	if state.fight_ticks(cfg.battle.deploy_ticks()) >= cfg.battle.time_limit_ticks():
		var k := strengths(state, cfg, setup)
		state.timed_out = true
		_finish(state, 0 if k[0] > k[1] else 1)


## [attacker K, defender K] by AutoResolve.strengths() for the companies still fighting.
static func strengths(
	state: BattleState, cfg: CombatConfig, setup: BattleSetup
) -> PackedFloat64Array:
	var current := BattleSetup.new()
	current.terrain = setup.terrain
	current.defender_wall = setup.defender_wall
	current.is_winter = setup.is_winter
	_copy_side(state, setup.attacker, current.attacker, 0)
	_copy_side(state, setup.defender, current.defender, 1)
	return AutoResolve.strengths(cfg, current)


static func result(state: BattleState, setup: BattleSetup, tick_rate: int) -> BattleResult:
	var outcome := BattleResult.new()
	outcome.attacker_won = state.winner == 0
	outcome.attacker_health = _health(state, setup.attacker, 0)
	outcome.defender_health = _health(state, setup.defender, 1)
	outcome.attacker_leader_captured = _captured(state, 0)
	outcome.defender_leader_captured = _captured(state, 1)
	outcome.duration = float(state.tick) / tick_rate
	return outcome


static func _has_fighters(state: BattleState, s: int) -> bool:
	for c: int in state.company_count():
		if state.side[c] == s and not state.is_leader(c):
			if state.status[c] == BattleState.Status.ACTIVE:
				return true
	return false


static func _finish(state: BattleState, winner: int) -> void:
	state.winner = winner
	state.phase = BattleState.Phase.OVER


## The side as it stands now: fleeing and fled companies count with no health; the real-time
## battle has no human malus.
static func _copy_side(state: BattleState, source: BattleSide, target: BattleSide, s: int) -> void:
	target.owner = source.owner
	target.morale_bonus = source.morale_bonus
	target.leadership = source.leadership
	target.has_leader = state.leader[s] >= 0 and state.is_present(state.leader[s])
	for c: int in state.company_count():
		if state.side[c] != s or state.is_leader(c):
			continue
		var fighting := state.status[c] == BattleState.Status.ACTIVE
		target.add_company(state.unit_ids[c], state.hp[c] / state.max_hp[c] if fighting else 0.0)


static func _health(state: BattleState, source: BattleSide, s: int) -> PackedFloat64Array:
	var health := PackedFloat64Array()
	health.resize(source.company_count())
	for c: int in state.company_count():
		if state.side[c] == s and not state.is_leader(c):
			health[state.setup_index[c]] = state.hp[c] / state.max_hp[c]
	return health


static func _captured(state: BattleState, s: int) -> bool:
	var leader := state.leader[s]
	return leader >= 0 and state.status[leader] == BattleState.Status.CAPTURED
