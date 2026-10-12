class_name JoustSim
extends RefCounted
## Deterministic joust at a fixed tick: a JoustSetup goes in, one JoustInput per rider and tick
## drives it, a JoustResult comes out. No devices, clocks or random numbers: the lance sways in
## a fixed pattern from the horse's gait; the computer's errors come from JoustAI.
##
## Timeline: herald's call, then per pass ready, run-up (spur on the gait's beats), aim, clash
## (impact at its start, scored once the couching window has passed) and the ride back; the
## ceremony ends the joust. Points decide after the regular passes, then stance, then up to
## `deciding_passes` extra passes; still level, the opponent keeps the field.

var cfg: JoustConfig
var setup: JoustSetup
var state := JoustState.new()


func _init(config: JoustConfig, joust_setup: JoustSetup) -> void:
	cfg = config
	setup = joust_setup
	var owners := joust_setup.owners()
	var lances := joust_setup.lances()
	for r: int in JoustState.RIDERS:
		var rider := JoustRider.new()
		rider.owner = owners[r]
		rider.lance = lances[r]
		rider.window = cfg.window_seconds(lances[r], owners[r])
		rider.sway_scale = cfg.sway_scale(lances[r])
		rider.stance = cfg.stance
		rider.reset_pass(cfg.tempo_start, cfg.aim_rest, cfg.beats())
		state.riders.append(rider)


## Plays a whole joust with the computer on both sides (auto-resolve, tests).
static func play_out(
	config: JoustConfig, joust_setup: JoustSetup, seed_value: int, player_skill: int
) -> JoustResult:
	var sim := JoustSim.new(config, joust_setup)
	var player := JoustAI.for_skill(config, 0, player_skill, seed_value)
	var opponent := JoustAI.for_skill(config, 1, joust_setup.opponent_skill, seed_value)
	var limit := sim.max_ticks()
	while not sim.is_over() and sim.state.tick < limit:
		sim.step(player.think(sim), opponent.think(sim))
	return sim.result()


func tick_seconds() -> float:
	return 1.0 / cfg.tick_rate


func is_over() -> bool:
	return state.phase == JoustState.Phase.OVER


## Upper bound of a joust's length, every deciding pass included.
func max_ticks() -> int:
	var per_pass := cfg.ticks(cfg.ready_seconds) + _runup_ticks() + _aim_ticks()
	per_pass += cfg.ticks(cfg.clash_seconds) + cfg.ticks(cfg.return_seconds)
	var passes := cfg.passes + cfg.deciding_passes
	return cfg.ticks(cfg.intro_seconds) + passes * per_pass + cfg.ticks(cfg.finale_seconds) + 1


## Ticks since the current pass's run-up began; the next step covers this tick of the pass.
func pass_tick() -> int:
	return state.tick - state.pass_start_tick


## Seconds since the current pass's run-up began, at the start of the next step.
func pass_time() -> float:
	return pass_tick() * tick_seconds()


func aim_start_time() -> float:
	return _runup_ticks() * tick_seconds()


func impact_time() -> float:
	return (_runup_ticks() + _aim_ticks()) * tick_seconds()


## When the gait's beat b falls in the run-up (seconds into the pass).
func beat_time(beat: int) -> float:
	return (beat + 0.5) * cfg.beat_seconds


## The lance tip's sway at a time of the pass: a fixed figure from the horse's gait, steadied
## by the lance skill and wilder above the ideal tempo.
func sway(rider: int, time: float) -> Vector2:
	var r := state.riders[rider]
	var phase := cfg.sway_pass_phase[maxi(state.pass_count - 1, 0) % cfg.sway_pass_phase.size()]
	var scale := r.sway_scale * (1.0 + cfg.overspeed_sway * maxf(0.0, r.tempo - cfg.tempo_ideal))
	return Vector2(
		cfg.sway_amplitude.x * sin(TAU * (time / cfg.sway_period.x + phase)),
		cfg.sway_amplitude.y * sin(TAU * (time / cfg.sway_period.y + phase))
	) * scale


func step(input_0: JoustInput, input_1: JoustInput) -> void:
	if is_over():
		return
	state.events.clear()
	var inputs: Array[JoustInput] = [input_0, input_1]
	for r: int in JoustState.RIDERS:
		_take_input(r, inputs[r] if inputs[r] != null else JoustInput.new())
	state.tick += 1
	state.phase_tick += 1
	if state.phase in [JoustState.Phase.RUNUP, JoustState.Phase.AIM]:
		for r: int in JoustState.RIDERS:
			_steer(r)
	_advance()


func result() -> JoustResult:
	var result := JoustResult.new()
	result.won = state.winner == JoustResult.PLAYER
	result.player_points = state.riders[0].points
	result.opponent_points = state.riders[1].points
	result.unseated = state.unseated
	result.passes = state.pass_count
	result.player_stance = state.riders[0].stance
	result.opponent_stance = state.riders[1].stance
	result.decided_by = state.decided_by
	result.duration = state.tick * tick_seconds()
	return result


func _take_input(r: int, input: JoustInput) -> void:
	var rider := state.riders[r]
	rider.shield = input.shield.limit_length(1.0) if input.shield.is_finite() else Vector2.ZERO
	var aim := input.aim.clamp(-Vector2.ONE, Vector2.ONE) if input.aim.is_finite() else Vector2.ZERO
	rider.aim_target = aim * cfg.aim_range
	var start := pass_time()
	if state.phase == JoustState.Phase.RUNUP and _pressed(input.spur):
		_spur(r, start + input.spur * tick_seconds())
	if state.phase in [JoustState.Phase.AIM, JoustState.Phase.CLASH] and _pressed(input.strike):
		var offset := start + input.strike * tick_seconds() - impact_time()
		var too_late := offset > cfg.couch_window_ms / 1000.0 + JoustStrike.EPSILON
		if is_nan(rider.strike_offset) and not too_late:
			rider.strike_offset = offset
			state.events.append(JoustEvent.new(JoustEvent.Kind.STRIKE, r))


func _spur(r: int, time: float) -> void:
	var rider := state.riders[r]
	var beat := clampi(roundi(time / cfg.beat_seconds - 0.5), 0, cfg.beats() - 1)
	var on_beat := (
		absf(time - beat_time(beat)) <= cfg.beat_window_ms / 1000.0 + JoustStrike.EPSILON
		and rider.spurred[beat] == 0
	)
	if on_beat:
		rider.spurred[beat] = 1
	var change := cfg.tempo_on_beat if on_beat else cfg.tempo_off_beat
	rider.tempo = clampf(rider.tempo + change, 0.0, cfg.tempo_max)
	rider.last_spur_on_beat = on_beat
	state.events.append(JoustEvent.new(JoustEvent.Kind.SPUR, r))


func _steer(r: int) -> void:
	var rider := state.riders[r]
	if state.phase == JoustState.Phase.AIM:
		rider.hand = rider.hand.move_toward(rider.aim_target, cfg.aim_speed * tick_seconds())
	rider.tip = rider.hand + sway(r, pass_time())


func _advance() -> void:
	var elapsed := state.phase_tick
	match state.phase:
		JoustState.Phase.INTRO:
			if elapsed >= cfg.ticks(cfg.intro_seconds):
				_begin(JoustState.Phase.READY)
		JoustState.Phase.READY:
			if elapsed >= cfg.ticks(cfg.ready_seconds):
				_start_pass()
		JoustState.Phase.RUNUP:
			if elapsed >= _runup_ticks():
				_begin(JoustState.Phase.AIM)
		JoustState.Phase.AIM:
			if elapsed >= _aim_ticks():
				_impact()
		JoustState.Phase.CLASH:
			if elapsed == _resolve_ticks():
				_resolve()
			if elapsed >= cfg.ticks(cfg.clash_seconds):
				_after_pass()
		JoustState.Phase.RETURN:
			if elapsed >= cfg.ticks(cfg.return_seconds):
				_begin(JoustState.Phase.READY)
		JoustState.Phase.FINALE:
			if elapsed >= cfg.ticks(cfg.finale_seconds):
				_begin(JoustState.Phase.OVER)
				state.events.append(JoustEvent.new(JoustEvent.Kind.OVER))


func _begin(phase: JoustState.Phase) -> void:
	state.phase = phase
	state.phase_tick = 0


func _start_pass() -> void:
	state.pass_count += 1
	state.pass_start_tick = state.tick
	for rider: JoustRider in state.riders:
		rider.reset_pass(cfg.tempo_start, cfg.aim_rest, cfg.beats())
	for r: int in JoustState.RIDERS:
		state.riders[r].tip = cfg.aim_rest + sway(r, 0.0)
	_begin(JoustState.Phase.RUNUP)
	state.events.append(JoustEvent.new(JoustEvent.Kind.PASS_START))


func _impact() -> void:
	for rider: JoustRider in state.riders:
		rider.impact_tip = rider.tip
		rider.impact_shield = rider.shield
	_begin(JoustState.Phase.CLASH)
	state.events.append(JoustEvent.new(JoustEvent.Kind.IMPACT))


func _resolve() -> void:
	for r: int in JoustState.RIDERS:
		JoustStrike.attack(cfg, state.riders[r], state.riders[1 - r])
		state.events.append(JoustEvent.new(JoustEvent.Kind.HIT, r))
	var down: Array[bool] = [state.riders[0].stance < 0.0, state.riders[1].stance < 0.0]
	if not (down[0] or down[1]):
		return
	var loser := 0 if down[0] else 1
	if down[0] and down[1]:
		loser = 1 if _leader() == 0 else 0
	state.riders[loser].unseated = true
	state.unseated = loser
	state.winner = 1 - loser
	state.decided_by = JoustResult.Decision.UNSEATED
	state.events.append(JoustEvent.new(JoustEvent.Kind.UNSEAT, loser))


func _after_pass() -> void:
	if state.winner >= 0:
		_finale()
		return
	if state.pass_count < cfg.passes:
		_begin(JoustState.Phase.RETURN)
		return
	var leader := _leader()
	if leader >= 0:
		state.winner = leader
		var level := state.riders[0].points == state.riders[1].points
		state.decided_by = JoustResult.Decision.STANCE if level else JoustResult.Decision.POINTS
		_finale()
	elif state.pass_count < cfg.passes + cfg.deciding_passes:
		_begin(JoustState.Phase.RETURN)
		state.events.append(JoustEvent.new(JoustEvent.Kind.DECIDING_PASS))
	else:
		state.winner = JoustResult.OPPONENT
		state.decided_by = JoustResult.Decision.STATUS_QUO
		_finale()


func _finale() -> void:
	_begin(JoustState.Phase.FINALE)
	state.events.append(JoustEvent.new(JoustEvent.Kind.FINALE, state.winner))


## The rider ahead on points, then on stance; -1 when level.
func _leader() -> int:
	var a := state.riders[0]
	var b := state.riders[1]
	if a.points != b.points:
		return 0 if a.points > b.points else 1
	if not is_equal_approx(a.stance, b.stance):
		return 0 if a.stance > b.stance else 1
	return -1


func _runup_ticks() -> int:
	return cfg.ticks(cfg.runup_seconds)


func _aim_ticks() -> int:
	return cfg.ticks(cfg.aim_seconds)


## Ticks after the impact until every press inside the couching window has arrived.
func _resolve_ticks() -> int:
	return ceili(cfg.couch_window_ms / 1000.0 * cfg.tick_rate - JoustStrike.EPSILON)


static func _pressed(fraction: float) -> bool:
	return fraction >= 0.0 and fraction <= 1.0
