class_name BattleDeployment
extends RefCounted
## Builds the starting BattleState from a BattleSetup: attacker on the left, defender on the
## right, infantry in front, archers behind, cavalry and leader on the right wing.

const JITTER := 0.15


static func create(cfg: CombatConfig, setup: BattleSetup, seed_value: int) -> BattleState:
	var rules := cfg.battle
	var state := BattleState.new()
	_add_side(state, cfg, setup.attacker, 0)
	_add_side(state, cfg, setup.defender, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_spawn_figures(state, rules, rng)
	for s: int in BattleState.SIDES:
		_layout_side(state, rules, s)
	return state


## Moves a company and its figures to pos at once, facing the given angle.
static func place(
	state: BattleState, rules: BattleRules, company: int, at: Vector2, angle: float
) -> void:
	state.pos[company] = at
	state.facing[company] = angle
	state.order[company] = BattleState.Order.HOLD
	state.order_point[company] = at
	if state.group[company] == BattleState.Group.SIEGE:
		var reach := minf(state.stats[company].attack_range, rules.siege_start_aim)
		state.aim_point[company] = (at + Vector2.from_angle(angle) * reach).clamp(
			Vector2.ZERO, rules.field_size
		)
	var slots := company_slots(state, rules, company)
	for k: int in slots.size():
		var f := state.fig_start[company] + k
		state.fig_pos[f] = at + (slots[k] + state.fig_jitter[f]).rotated(angle)


static func company_slots(
	state: BattleState, rules: BattleRules, company: int
) -> PackedVector2Array:
	var rule := rules.formation(state.group[company], state.formation[company])
	var count := maxi(1, state.alive_figures(company))
	return BattleFormations.slots(rule.shape, count, figure_spacing(state, rules, company))


static func figure_spacing(state: BattleState, rules: BattleRules, company: int) -> float:
	if state.group[company] == BattleState.Group.CAVALRY:
		return rules.horse_spacing
	return rules.foot_spacing


static func figure_radius(state: BattleState, rules: BattleRules, company: int) -> float:
	if state.group[company] == BattleState.Group.CAVALRY:
		return rules.horse_radius
	return rules.foot_radius


static func _add_side(state: BattleState, cfg: CombatConfig, side: BattleSide, s: int) -> void:
	var leadership_morale := 0.0
	if side.has_leader:
		leadership_morale = cfg.morale_per_leadership * side.leadership
	for i: int in side.company_count():
		var health := side.health[i] if i < side.health.size() else 1.0
		var id := side.units[i]
		if not cfg.units.has(id):
			push_error("battle setup: unknown unit '%s'" % id)
			id = "levy" if cfg.units.has("levy") else "leader"
			health = 0.0
		_add_company(state, cfg.units[id], id, s, i, health)
		state.start_morale.append(cfg.units[id].morale + side.morale_bonus + leadership_morale)
	if side.has_leader:
		state.leader[s] = state.company_count()
		_add_company(state, cfg.units["leader"], "leader", s, -1, 1.0)
		state.start_morale.append(0.0)
	for g: int in CombatConfig.GROUPS.size():
		if not state.members(s, g).is_empty():
			state.side_groups[s].append(g)
	if not state.side_groups[s].is_empty():
		state.active_group[s] = state.side_groups[s][0]


static func _add_company(
	state: BattleState,
	stats: CombatConfig.UnitStats,
	id: String,
	s: int,
	setup_index: int,
	health: float
) -> void:
	state.stats.append(stats)
	state.unit_ids.append(id)
	state.side.append(s)
	state.group.append(maxi(0, CombatConfig.GROUPS.find(stats.group)))
	state.setup_index.append(setup_index)
	state.max_hp.append(stats.hp)
	state.hp.append(stats.hp * clampf(health, 0.0, 1.0))
	var destroyed := health <= 0.0
	state.status.append(BattleState.Status.DESTROYED if destroyed else BattleState.Status.ACTIVE)
	state.pos.append(Vector2.ZERO)
	state.facing.append(0.0)
	state.speed.append(0.0)
	state.radius.append(0.0)
	state.morale.append(0.0)
	state.shock.append(0.0)
	state.order.append(BattleState.Order.HOLD)
	state.order_point.append(Vector2.ZERO)
	state.order_target.append(-1)
	state.charge_run.append(0.0)
	state.formation.append(0)
	state.bolts.append(0)
	state.reload_timer.append(0.0)
	state.volley_cooldown.append(0.0)
	state.fire_pending.append(0)
	state.aim_point.append(Vector2.ZERO)
	state.shot_point.append(Vector2.ZERO)
	state.shot_timer.append(-1.0)
	state.contact.append(-1)
	state.last_contact_tick.append(BattleState.NO_TICK)
	state.fig_start.append(0)
	state.fig_count.append(maxi(1, stats.figures))


static func _layout_side(state: BattleState, rules: BattleRules, s: int) -> void:
	var forward := Vector2.RIGHT if s == 0 else Vector2.LEFT
	var right := forward.orthogonal() * -1.0
	var front_x := rules.deploy_depth - rules.deployment["front_gap"]
	var origin_x := front_x if s == 0 else rules.field_size.x - front_x
	var origin := Vector2(origin_x, rules.field_size.y / 2)
	var infantry := _row(state, rules, s, BattleState.Group.INFANTRY)
	var span := _row_width(state, rules, infantry)
	_place_row(state, rules, infantry, origin, forward, right, 0.0)
	_place_row(
		state, rules, _row(state, rules, s, BattleState.Group.ARCHERS),
		origin - forward * rules.deployment["archer_depth"], forward, right, 0.0
	)
	_place_row(
		state, rules, _row(state, rules, s, BattleState.Group.SIEGE),
		origin - forward * rules.deployment["siege_depth"], forward, right, 0.0
	)
	var cavalry := _row(state, rules, s, BattleState.Group.CAVALRY)
	var leader := state.leader[s]
	var knights := PackedInt32Array()
	for c: int in cavalry:
		if c != leader:
			knights.append(c)
	var wing := span * 0.5 + rules.deployment["company_gap"] + _row_width(state, rules, knights) * 0.5
	_place_row(
		state, rules, knights, origin - forward * rules.deployment["cavalry_depth"],
		forward, right, wing
	)
	if leader >= 0:
		var depth := rules.deployment["cavalry_depth"] + rules.deployment["leader_depth"]
		var at := origin - forward * depth + right * wing
		at = at.clamp(Vector2.ONE * 2.0, rules.field_size - Vector2.ONE * 2.0)
		place(state, rules, leader, at, forward.angle())


static func _row(state: BattleState, rules: BattleRules, s: int, g: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for c: int in state.members(s, g):
		if state.is_present(c):
			state.radius[c] = BattleFormations.radius(
				company_slots(state, rules, c), figure_radius(state, rules, c)
			)
			result.append(c)
	return result


static func _row_width(state: BattleState, rules: BattleRules, row: PackedInt32Array) -> float:
	var width := 0.0
	for c: int in row:
		width += state.radius[c] * 2.0 + rules.deployment["company_gap"]
	return maxf(0.0, width - rules.deployment["company_gap"])


static func _place_row(
	state: BattleState,
	rules: BattleRules,
	row: PackedInt32Array,
	center: Vector2,
	forward: Vector2,
	right: Vector2,
	lateral: float
) -> void:
	var offset := lateral - _row_width(state, rules, row) * 0.5
	for c: int in row:
		offset += state.radius[c]
		var at := center + right * offset
		var margin := Vector2.ONE * state.radius[c]
		at = at.clamp(margin, rules.field_size - margin)
		place(state, rules, c, at, forward.angle())
		offset += state.radius[c] + rules.deployment["company_gap"]


static func _spawn_figures(
	state: BattleState, rules: BattleRules, rng: RandomNumberGenerator
) -> void:
	for c: int in state.company_count():
		state.fig_start[c] = state.fig_pos.size()
		var jitter := figure_spacing(state, rules, c) * JITTER
		for k: int in state.fig_count[c]:
			state.fig_company.append(c)
			state.fig_jitter.append(
				Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
			)
			state.fig_pos.append(state.pos[c])
		# Crossbows hold rules.volleys volleys; a siege engine holds one loaded stone.
		var loads := 1 if state.group[c] == BattleState.Group.SIEGE else rules.volleys
		state.bolts[c] = loads if state.stats[c].ranged > 0.0 else 0
