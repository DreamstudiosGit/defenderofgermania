class_name RaidSim
extends RefCounted
## Deterministic castle raid at a fixed tick: a RaidSetup goes in, one RaidInput per tick
## drives the leader, a RaidResult comes out. No devices, clocks or global random numbers; the
## seed picks the sneak paths and where each guard starts in its patterns.

var cfg: RaidConfig
var setup: RaidSetup
var layout: RaidLayout
var state := RaidState.new()
## Problems of the setup; a raid with errors is over before it starts.
var errors := PackedStringArray()

var _rng := RandomNumberGenerator.new()


func _init(config: RaidConfig, raid_setup: RaidSetup, seed_value: int) -> void:
	cfg = config
	setup = raid_setup.copy()
	errors = setup.validate(cfg)
	if not errors.is_empty():
		for error: String in errors:
			push_error("raid setup: %s" % error)
		layout = RaidLayout.new()
		state.over = true
		return
	_rng.seed = seed_value
	layout = RaidLayout.build(cfg, setup, _rng)
	var leader := state.leader
	leader.x = RaidLayout.START_X
	leader.health = cfg.leader_health
	leader.max_health = cfg.leader_health
	leader.stamina = cfg.stamina
	leader.start(RaidFighter.Action.READY)
	state.guards = RaidGuards.create(cfg, layout, setup.guard_skill, _rng)
	state.reinforcements_left = layout.reinforcements


func tick_seconds() -> float:
	return 1.0 / cfg.tick_rate


func is_over() -> bool:
	return state.over


func elapsed_seconds() -> float:
	return state.tick * tick_seconds()


func seconds_left() -> float:
	return maxf(0.0, cfg.time_limit_seconds - elapsed_seconds())


func step(input: RaidInput) -> void:
	if state.over:
		return
	state.events.clear()
	state.tick += 1
	var clean := _sanitized(input)
	if clean.flee:
		_finish(RaidResult.Outcome.ESCAPED_WOUNDED)
		return
	_alarm()
	RaidDuel.advance(state.leader, cfg)
	RaidDuel.rest(state.leader, cfg)
	for guard: RaidFighter in state.guards:
		if guard.is_active():
			RaidDuel.advance(guard, cfg)
	RaidMoves.update(state, cfg, layout, setup, clean)
	RaidGuards.update_front(state, cfg)
	RaidGuards.move(state, cfg, layout)
	RaidGuards.think(state, cfg)
	RaidDuel.command(state, cfg, setup.blade, clean)
	RaidDuel.resolve(state, cfg, setup.blade)
	RaidGuards.update_front(state, cfg)
	if state.leader.is_down():
		_finish(RaidResult.Outcome.CAPTURED)
	elif state.deed_progress >= 1.0:
		_finish(RaidResult.Outcome.SUCCESS)
	elif state.tick >= cfg.seconds_to_ticks(cfg.time_limit_seconds):
		_finish(RaidResult.Outcome.ESCAPED_WOUNDED)


func result() -> RaidResult:
	var result := RaidResult.new()
	result.target = setup.target
	result.outcome = state.outcome
	result.success = state.over and state.outcome == RaidResult.Outcome.SUCCESS
	result.time_used = elapsed_seconds()
	result.alarm_raised = state.alarm
	result.guards_defeated = state.count_guards(true)
	result.guards_avoided = state.count_guards(false)
	result.practice = setup.practice
	return result


## After the alarm, reinforcements come through the far door one by one.
func _alarm() -> void:
	if not state.alarm and state.tick >= cfg.seconds_to_ticks(cfg.alarm_seconds):
		state.alarm = true
		state.next_reinforcement_tick = state.tick
		state.events.append(RaidEvent.new(RaidEvent.Kind.ALARM))
	if not state.alarm or state.reinforcements_left <= 0:
		return
	if state.tick < state.next_reinforcement_tick:
		return
	var guard := RaidGuards.make_guard(cfg, setup.guard_skill, layout.end_x, _rng, true)
	state.guards.append(guard)
	state.reinforcements_left -= 1
	state.next_reinforcement_tick += cfg.seconds_to_ticks(cfg.layout.reinforcement_interval_seconds)
	state.events.append(RaidEvent.new(RaidEvent.Kind.REINFORCEMENT, state.guards.size() - 1))


func _finish(outcome: RaidResult.Outcome) -> void:
	state.over = true
	state.outcome = outcome


## Never trusts the device: out-of-range values become "nothing".
static func _sanitized(input: RaidInput) -> RaidInput:
	var clean := RaidInput.new()
	if input == null:
		return clean
	clean.move = clampf(input.move, -1.0, 1.0) if is_finite(input.move) else 0.0
	clean.strike = input.strike if input.strike >= 0 and input.strike <= 2 else -1
	clean.parry = input.parry if input.parry >= 0 and input.parry <= 2 else -1
	clean.act = input.act
	clean.flee = input.flee
	return clean
