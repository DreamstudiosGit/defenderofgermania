class_name MerchantEscorts
extends RefCounted
## Escort soldiers with a fixed pattern per skill: walk beside their wagon's driver; go for the
## nearest raider within notice range (wider once the first wagon stopped); shield up, wind up
## behind the shield, strike, recover — always in this order and timing; a leader who pulls a
## driver gets the wind-up at once. A parried blow staggers them; losing their guard sends
## them into the ditch for a while. Companies that reach them hold them until the fight is
## decided.

## An escort lets go of a raider this much beyond his notice range.
const LEASH := 1.6
## Escorts keep this share of their reach between themselves and their target.
const SPACING := 0.7
## A blow lands this far beyond the reach: the leader cannot dodge by a hair.
const REACH_SLACK := 0.3


static func update(sim: MerchantSim, dt: float) -> void:
	var s := sim.state
	for e: int in s.escort_count():
		s.escort_timer[e] = maxf(0.0, s.escort_timer[e] - dt)
		match s.escort_state[e]:
			MerchantState.Escort.PATROL:
				_patrol(sim, e, dt)
			MerchantState.Escort.APPROACH:
				_approach(sim, e, dt)
			MerchantState.Escort.COVER:
				_cover(sim, e, dt)
			MerchantState.Escort.WINDUP:
				if _target_valid(sim, e):
					_close_in(sim, e, target_x(s, e), dt)
				if s.escort_timer[e] <= 0.0:
					_blow(sim, e)
			MerchantState.Escort.RECOVER:
				if _target_valid(sim, e):
					_close_in(sim, e, target_x(s, e), dt)
				if s.escort_timer[e] <= 0.0:
					_engage(sim, e)
			MerchantState.Escort.STAGGERED:
				if s.escort_timer[e] <= 0.0:
					_engage(sim, e)
			MerchantState.Escort.DOWN:
				if s.escort_timer[e] <= 0.0:
					s.escort_guard[e] = sim.escort.guard
					s.escort_state[e] = MerchantState.Escort.PATROL
					s.events.append(MerchantEvent.new(MerchantEvent.Kind.ESCORT_UP, -1, e))
		s.escort_x[e] = minf(s.escort_x[e], s.gate_x - 1.0)


## Into the ditch; whoever held him lets go.
static func knock_down(sim: MerchantSim, e: int, raider: int) -> void:
	var s := sim.state
	s.escort_state[e] = MerchantState.Escort.DOWN
	s.escort_timer[e] = sim.escort.down_seconds
	s.escort_guard[e] = 0.0
	s.events.append(MerchantEvent.new(MerchantEvent.Kind.ESCORT_DOWN, -1, e, raider))


## Shield up: from cover until the blow, strikes glance off.
static func guarded(s: MerchantState, e: int) -> bool:
	var state := s.escort_state[e]
	return state == MerchantState.Escort.COVER or state == MerchantState.Escort.WINDUP


## x of the escort's target: the leader or a company.
static func target_x(s: MerchantState, e: int) -> float:
	var target := s.escort_target[e]
	return s.leader_x if target == MerchantState.LEADER else s.company_x[target]


static func _patrol(sim: MerchantSim, e: int, dt: float) -> void:
	var s := sim.state
	if not s.is_rolling(s.escort_post[e]):
		s.escort_post[e] = _nearest_rolling(sim, s.escort_x[e], s.escort_post[e])
	var post := s.escort_post[e]
	_walk(sim, e, s.wagon_x[post] + s.escort_post_offset[e], dt)
	var target := _threat(sim, e)
	if target != -2:
		s.escort_target[e] = target
		s.escort_state[e] = MerchantState.Escort.APPROACH


static func _approach(sim: MerchantSim, e: int, dt: float) -> void:
	var s := sim.state
	if not _target_valid(sim, e):
		s.escort_state[e] = MerchantState.Escort.PATROL
		return
	var goal := target_x(s, e)
	if absf(goal - s.escort_x[e]) > sim.notice_range() * LEASH:
		s.escort_state[e] = MerchantState.Escort.PATROL
		return
	_close_in(sim, e, goal, dt)
	if absf(goal - s.escort_x[e]) > sim.cfg.escort_reach:
		return
	var target := s.escort_target[e]
	if target != MerchantState.LEADER:
		MerchantCompanies.bind(sim, target, e)
		return
	s.escort_state[e] = MerchantState.Escort.COVER
	s.escort_timer[e] = sim.escort.cover_seconds
	_cover(sim, e, 0.0)


static func _cover(sim: MerchantSim, e: int, dt: float) -> void:
	var s := sim.state
	if not _target_valid(sim, e):
		s.escort_state[e] = MerchantState.Escort.PATROL
		return
	var goal := target_x(s, e)
	_close_in(sim, e, goal, dt)
	if absf(goal - s.escort_x[e]) > sim.cfg.escort_reach + REACH_SLACK:
		s.escort_state[e] = MerchantState.Escort.APPROACH
		return
	# Hands off the driver: an escort beside a leader who pulls winds up at once.
	if s.escort_target[e] == MerchantState.LEADER and s.pull_wagon >= 0:
		s.escort_timer[e] = 0.0
	if s.escort_timer[e] <= 0.0:
		s.escort_state[e] = MerchantState.Escort.WINDUP
		s.escort_timer[e] = sim.escort.windup_seconds
		s.events.append(MerchantEvent.new(MerchantEvent.Kind.WINDUP, -1, e))


## The blow at the end of the wind-up: parried, landed or into thin air.
static func _blow(sim: MerchantSim, e: int) -> void:
	var s := sim.state
	var in_reach := absf(s.leader_x - s.escort_x[e]) <= sim.cfg.escort_reach + REACH_SLACK
	if s.escort_target[e] == MerchantState.LEADER and in_reach and not s.captured:
		if s.parry_open > 0.0:
			s.escort_state[e] = MerchantState.Escort.STAGGERED
			s.escort_timer[e] = sim.cfg.stagger_seconds
			s.events.append(MerchantEvent.new(MerchantEvent.Kind.PARRIED, -1, e))
			return
		MerchantLeader.take_blow(sim, e)
	s.escort_state[e] = MerchantState.Escort.RECOVER
	s.escort_timer[e] = sim.escort.recover_seconds


## After a blow or a stagger: shield up again if the target is close, else after it.
static func _engage(sim: MerchantSim, e: int) -> void:
	var s := sim.state
	if not _target_valid(sim, e):
		s.escort_state[e] = MerchantState.Escort.PATROL
	elif absf(target_x(s, e) - s.escort_x[e]) <= sim.cfg.escort_reach:
		s.escort_state[e] = MerchantState.Escort.COVER
		s.escort_timer[e] = sim.escort.cover_seconds
	else:
		s.escort_state[e] = MerchantState.Escort.APPROACH


## The nearest raider within notice range: LEADER, a company index, or -2 for nobody.
static func _threat(sim: MerchantSim, e: int) -> int:
	var s := sim.state
	var best := -2
	var nearest := sim.notice_range()
	if not s.captured and absf(s.leader_x - s.escort_x[e]) <= nearest:
		best = MerchantState.LEADER
		nearest = absf(s.leader_x - s.escort_x[e])
	for c: int in s.company_count():
		var state := s.company_state[c]
		var hunting := state == MerchantState.Company.RUNNING
		if hunting or state == MerchantState.Company.PULLING:
			var distance := absf(s.company_x[c] - s.escort_x[e])
			if distance < nearest:
				best = c
				nearest = distance
	return best


static func _target_valid(sim: MerchantSim, e: int) -> bool:
	var s := sim.state
	var target := s.escort_target[e]
	if target == MerchantState.LEADER:
		return not s.captured
	var state := s.company_state[target]
	return state == MerchantState.Company.RUNNING or state == MerchantState.Company.PULLING


static func _nearest_rolling(sim: MerchantSim, x: float, fallback: int) -> int:
	var s := sim.state
	var best := fallback
	var nearest := INF
	for w: int in s.wagon_count():
		if s.is_rolling(w) and absf(s.wagon_x[w] - x) < nearest:
			best = w
			nearest = absf(s.wagon_x[w] - x)
	return best


## Walks up to the target but keeps a little space, like a man with a spear would.
static func _close_in(sim: MerchantSim, e: int, goal: float, dt: float) -> void:
	var s := sim.state
	var side := signf(s.escort_x[e] - goal)
	if side == 0.0:
		side = -1.0
	_walk(sim, e, goal + side * sim.cfg.escort_reach * SPACING, dt)


static func _walk(sim: MerchantSim, e: int, goal: float, dt: float) -> void:
	var s := sim.state
	s.escort_x[e] = move_toward(s.escort_x[e], goal, sim.escort.speed * dt)
