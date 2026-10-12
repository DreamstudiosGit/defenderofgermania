class_name RaidDuel
extends RefCounted
## Blows and parries. A blow lands when its windup is full. A guard covering the blow's height
## blocks it; otherwise it hits (a guard in its own windup only takes part of the damage and
## strikes on).
## The leader parries a guard's blow with a parry at the same height pressed at most
## 150 + 20 × blade ms before it lands; the parried guard stands open for a riposte.


## Counts the current action on and ends the timed ones; windups end in resolve().
static func advance(fighter: RaidFighter, cfg: RaidConfig) -> void:
	fighter.action_ticks += 1
	if fighter.action_length <= 0 or fighter.action == RaidFighter.Action.WINDUP:
		return
	if fighter.action_ticks < fighter.action_length:
		return
	if fighter.action == RaidFighter.Action.PARRY:
		fighter.start(RaidFighter.Action.RECOVER, cfg.ticks(cfg.parry_recover_ms))
	else:
		fighter.start(RaidFighter.Action.READY)
		fighter.idle_ticks = 0


## Stamina comes back after a pause without strikes or parries.
static func rest(leader: RaidFighter, cfg: RaidConfig) -> void:
	leader.rested_ticks += 1
	if leader.rested_ticks >= cfg.ticks(cfg.stamina_regen_delay_ms):
		leader.stamina = minf(cfg.stamina, leader.stamina + cfg.stamina_regen_per_second / cfg.tick_rate)


## The leader's strike or parry of this tick, if he is ready and has the stamina for it.
static func command(state: RaidState, cfg: RaidConfig, blade: int, input: RaidInput) -> void:
	var leader := state.leader
	if leader.action != RaidFighter.Action.READY or state.is_sneaking():
		return
	if input.parry >= 0:
		if not _spend(state, cfg.parry_cost):
			return
		leader.start(RaidFighter.Action.PARRY, cfg.parry_ticks(blade), input.parry)
		state.events.append(RaidEvent.new(RaidEvent.Kind.PARRY, RaidEvent.LEADER, input.parry))
	elif input.strike >= 0:
		if not _spend(state, cfg.strike_cost):
			return
		leader.start(RaidFighter.Action.WINDUP, cfg.ticks(cfg.strike_windup_ms), input.strike)
		state.events.append(RaidEvent.new(RaidEvent.Kind.STRIKE, RaidEvent.LEADER, input.strike))
		if state.engaged:
			RaidGuards.react(state.front_guard(), cfg, input.strike)


## Lands every blow whose windup is full: the leader's first, then the guards'.
static func resolve(state: RaidState, cfg: RaidConfig, blade: int) -> void:
	var leader := state.leader
	if leader.action == RaidFighter.Action.WINDUP and leader.ticks_left() <= 0:
		_leader_blow(state, cfg, blade)
	for i: int in state.guards.size():
		var guard := state.guards[i]
		if guard.action == RaidFighter.Action.WINDUP and guard.ticks_left() <= 0:
			_guard_blow(state, cfg, i)


static func _spend(state: RaidState, cost: float) -> bool:
	var leader := state.leader
	if leader.stamina < cost:
		state.events.append(RaidEvent.new(RaidEvent.Kind.TIRED))
		return false
	leader.stamina -= cost
	leader.rested_ticks = 0
	return true


static func _leader_blow(state: RaidState, cfg: RaidConfig, blade: int) -> void:
	var leader := state.leader
	var height := leader.height
	leader.start(RaidFighter.Action.RECOVER, cfg.ticks(cfg.strike_recover_ms))
	var guard := state.front_guard()
	if guard == null or guard.x - leader.x > cfg.reach or guard.action == RaidFighter.Action.POST:
		return
	var rules := cfg.guard_skills[guard.skill]
	if guard.action == RaidFighter.Action.READY and guard.stance == height:
		leader.start(RaidFighter.Action.RECOVER, cfg.ticks(cfg.blocked_recover_ms))
		# A block is the guard's cue: it strikes back at once.
		guard.idle_ticks = cfg.ticks(rules.idle_ms)
		state.events.append(RaidEvent.new(RaidEvent.Kind.BLOCKED, state.front, height))
		return
	var damage := cfg.strike_damage_for(blade)
	if guard.action == RaidFighter.Action.WINDUP:
		damage *= cfg.windup_damage_factor
	guard.health = maxf(0.0, guard.health - damage)
	state.events.append(RaidEvent.new(RaidEvent.Kind.HIT, state.front, height))
	if guard.health <= 0.0:
		guard.start(RaidFighter.Action.DOWN)
		state.events.append(RaidEvent.new(RaidEvent.Kind.DOWN, state.front))
		return
	if guard.action == RaidFighter.Action.WINDUP:
		return
	guard.start(RaidFighter.Action.STAGGER, cfg.ticks(cfg.guard_stagger_ms))
	guard.react_in = -1
	if rules.adapts:
		guard.stance = height
		guard.stance_ticks = 0


static func _guard_blow(state: RaidState, cfg: RaidConfig, index: int) -> void:
	var guard := state.guards[index]
	var leader := state.leader
	var rules := cfg.guard_skills[guard.skill]
	var height := guard.height
	var out_of_reach := state.is_sneaking() or guard.x - leader.x > cfg.reach
	if out_of_reach or leader.is_down():
		guard.start(RaidFighter.Action.RECOVER, cfg.ticks(rules.recover_ms))
		return
	if leader.action == RaidFighter.Action.PARRY and leader.height == height:
		guard.start(RaidFighter.Action.OPEN, cfg.ticks(rules.open_ms))
		guard.react_in = -1
		leader.start(RaidFighter.Action.READY)
		state.events.append(RaidEvent.new(RaidEvent.Kind.PARRIED, index, height))
		return
	guard.start(RaidFighter.Action.RECOVER, cfg.ticks(rules.recover_ms))
	leader.health = maxf(0.0, leader.health - rules.damage)
	state.events.append(RaidEvent.new(RaidEvent.Kind.HIT, RaidEvent.LEADER, height))
	if leader.health <= 0.0:
		leader.start(RaidFighter.Action.DOWN)
		state.events.append(RaidEvent.new(RaidEvent.Kind.DOWN, RaidEvent.LEADER))
	else:
		leader.start(RaidFighter.Action.STAGGER, cfg.ticks(cfg.leader_stagger_ms))
