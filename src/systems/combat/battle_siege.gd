class_name BattleSiege
extends RefCounted
## Siege engines (trebuchets): a target circle within range that the player moves, one stone
## per reload, a flight time before it lands, and area damage to every enemy company with
## standing figures inside the splash radius.

const LANDING_SLACK := 1e-6


static func update(
	state: BattleState, rules: BattleRules, damage: PackedFloat64Array, dt: float
) -> void:
	for c: int in state.company_count():
		if state.group[c] != BattleState.Group.SIEGE:
			continue
		_fly(state, rules, c, damage, dt)
		if state.status[c] != BattleState.Status.ACTIVE:
			continue
		var stats := state.stats[c]
		state.aim_point[c] = within_range(state, rules, c, state.aim_point[c])
		if state.bolts[c] < 1:
			state.reload_timer[c] += dt
			if state.reload_timer[c] >= stats.reload:
				state.reload_timer[c] = 0.0
				state.bolts[c] = 1
		var deployed := rules.formation(state.group[c], state.formation[c]).can_fire
		if state.fire_pending[c] == 0 or state.bolts[c] < 1 or not deployed:
			continue
		state.fire_pending[c] = 0
		state.bolts[c] = 0
		state.shot_point[c] = state.aim_point[c]
		state.shot_timer[c] = rules.siege_flight_seconds
		state.events.append(BattleEvent.new(BattleEvent.Kind.SHOT, state.side[c], c))


## Moves the target circles of the engines by a stick direction for one tick.
static func move_aim(
	state: BattleState, rules: BattleRules, engines: PackedInt32Array, move: Vector2
) -> void:
	var step := move * rules.siege_aim_speed / rules.tick_rate
	for c: int in engines:
		state.aim_point[c] = within_range(state, rules, c, state.aim_point[c] + step)


## Puts every engine's target circle on the point, as far as its range allows.
static func aim_at(
	state: BattleState, rules: BattleRules, engines: PackedInt32Array, point: Vector2
) -> void:
	for c: int in engines:
		state.aim_point[c] = within_range(state, rules, c, point)


## The engines throw as soon as they are loaded.
static func fire(state: BattleState, engines: PackedInt32Array) -> void:
	for c: int in engines:
		state.fire_pending[c] = 1


static func within_range(
	state: BattleState, rules: BattleRules, c: int, point: Vector2
) -> Vector2:
	var offset := (point - state.pos[c]).limit_length(state.stats[c].attack_range)
	return (state.pos[c] + offset).clamp(Vector2.ZERO, rules.field_size)


## A stone in the air lands even if its engine was destroyed meanwhile.
static func _fly(
	state: BattleState, rules: BattleRules, c: int, damage: PackedFloat64Array, dt: float
) -> void:
	if state.shot_timer[c] < 0.0:
		return
	state.shot_timer[c] -= dt
	# Summing 1/30 s ticks leaves a tiny remainder; the stone lands on its last tick.
	if state.shot_timer[c] > LANDING_SLACK:
		return
	state.shot_timer[c] = -1.0
	_blast(state, rules, c, damage)
	state.events.append(BattleEvent.new(BattleEvent.Kind.BLAST, state.side[c], c))


## Damage = (ranged - armor) times the share of the company's standing figures inside.
static func _blast(
	state: BattleState, rules: BattleRules, c: int, damage: PackedFloat64Array
) -> void:
	var stats := state.stats[c]
	var center := state.shot_point[c]
	var reach := stats.splash_radius * stats.splash_radius
	for e: int in state.company_count():
		if state.side[e] == state.side[c] or not state.is_present(e):
			continue
		var alive := state.alive_figures(e)
		var inside := 0
		for k: int in alive:
			if state.fig_pos[state.fig_start[e] + k].distance_squared_to(center) <= reach:
				inside += 1
		if inside == 0:
			continue
		var hit := BattleDamage.hit(stats.ranged, state.stats[e].armor, stats.armor_piercing)
		damage[e] += hit * inside / float(alive) * rules.cover_at(state.pos[e])
