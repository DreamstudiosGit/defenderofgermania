class_name MerchantLeader
extends RefCounted
## The raiding leader's tick: ride, parry, strike, shoot the crossbow or pull a driver off his
## box. Every input is validated here; a stunned leader does nothing.


static func update(sim: MerchantSim, input: MerchantInput, dt: float) -> void:
	var s := sim.state
	var cfg := sim.cfg
	s.stun = maxf(0.0, s.stun - dt)
	s.strike_cooldown = maxf(0.0, s.strike_cooldown - dt)
	s.parry_open = maxf(0.0, s.parry_open - dt)
	s.parry_cooldown = maxf(0.0, s.parry_cooldown - dt)
	s.reload = maxf(0.0, s.reload - dt)
	var move := clampf(input.move, -1.0, 1.0) if is_finite(input.move) else 0.0
	if s.captured or s.stun > 0.0:
		_release_pull(s)
		_ride(sim, 0.0, dt)
		return
	if input.parry and s.parry_cooldown <= 0.0:
		s.parry_open = sim.parry_window()
		s.parry_cooldown = cfg.parry_cooldown
		_release_pull(s)
		s.events.append(MerchantEvent.new(MerchantEvent.Kind.PARRY))
	elif input.pull and _pull(sim, dt):
		return
	else:
		_release_pull(s)
	if input.strike and s.strike_cooldown <= 0.0:
		_strike(sim)
	if input.shoot and s.reload <= 0.0 and s.bolts > 0:
		_shoot(sim)
	_ride(sim, move, dt)


## Hit by an escort: loses composure, lets go of the driver and is dazed for a moment.
static func take_blow(sim: MerchantSim, escort: int) -> void:
	var s := sim.state
	s.composure = maxi(0, s.composure - 1)
	s.stun = sim.cfg.stun_seconds
	s.leader_velocity = 0.0
	_release_pull(s)
	s.events.append(MerchantEvent.new(MerchantEvent.Kind.LEADER_HIT, -1, escort))
	if s.composure == 0:
		s.captured = true
		s.events.append(MerchantEvent.new(MerchantEvent.Kind.CAPTURED, -1, escort))


## Holds on to a driver within reach, riding along with his box. True while pulling.
static func _pull(sim: MerchantSim, dt: float) -> bool:
	var s := sim.state
	var w := s.pull_wagon
	if w < 0 or not s.is_rolling(w) or absf(sim.box_x(w) - s.leader_x) > sim.cfg.pull_reach:
		_release_pull(s)
		w = sim.pull_target()
	if w < 0:
		return false
	s.pull_wagon = w
	s.leader_x = sim.box_x(w)
	s.leader_velocity = sim.cfg.wagon_speed
	s.pull_progress += dt
	if s.pull_progress >= sim.cfg.pull_seconds:
		_release_pull(s)
		sim.stop_wagon(w, MerchantState.Stop.DRIVER, MerchantState.LEADER)
	return true


static func _release_pull(s: MerchantState) -> void:
	s.pull_wagon = -1
	s.pull_progress = 0.0


## The nearest escort in reach takes the blow — unless his shield is up or he winds up behind
## it; a staggered escort takes double.
static func _strike(sim: MerchantSim) -> void:
	var s := sim.state
	s.strike_cooldown = sim.cfg.strike_seconds
	var target := -1
	var nearest := sim.cfg.strike_reach
	for e: int in s.escort_count():
		var distance := absf(s.escort_x[e] - s.leader_x)
		if s.escort_state[e] != MerchantState.Escort.DOWN and distance <= nearest:
			target = e
			nearest = distance
	s.events.append(MerchantEvent.new(MerchantEvent.Kind.STRIKE, -1, target))
	if target < 0:
		return
	if MerchantEscorts.guarded(s, target):
		s.events.append(MerchantEvent.new(MerchantEvent.Kind.BLOCKED, -1, target))
		return
	var power := sim.strike_power()
	if s.escort_state[target] == MerchantState.Escort.STAGGERED:
		power *= 2.0
	s.escort_guard[target] -= power
	s.events.append(MerchantEvent.new(MerchantEvent.Kind.ESCORT_HIT, -1, target))
	if s.escort_guard[target] <= 0.0:
		MerchantEscorts.knock_down(sim, target, MerchantState.LEADER)


## A bolt at the harness of the horses ahead: it cuts the traces while the sway is calm.
static func _shoot(sim: MerchantSim) -> void:
	var s := sim.state
	s.reload = sim.cfg.reload_seconds
	s.bolts -= 1
	var target := sim.crossbow_target()
	if target >= 0 and absf(sim.sway()) <= sim.cfg.hit_window:
		sim.stop_wagon(target, MerchantState.Stop.HARNESS, MerchantState.LEADER)
	else:
		s.events.append(MerchantEvent.new(MerchantEvent.Kind.BOLT_MISSED, target))


static func _ride(sim: MerchantSim, move: float, dt: float) -> void:
	var s := sim.state
	var cfg := sim.cfg
	if move != 0.0:
		s.leader_facing = 1 if move > 0.0 else -1
	s.leader_velocity = move_toward(
		s.leader_velocity, move * cfg.leader_speed, cfg.leader_acceleration * dt
	)
	var lowest := cfg.leader_start()
	var highest := s.gate_x - cfg.gate_keep_away
	s.leader_x = clampf(s.leader_x + s.leader_velocity * dt, lowest, highest)
	if s.leader_x <= lowest or s.leader_x >= highest:
		s.leader_velocity = 0.0
