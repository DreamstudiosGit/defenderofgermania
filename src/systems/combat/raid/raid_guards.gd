class_name RaidGuards
extends RefCounted
## Guards follow fixed patterns per skill, no dice: each holds its post until the leader comes
## near, steps up, covers one height (cycling through its stances), attacks in a fixed order of
## heights and, from skill 1, turns its guard towards the leader's blow (on a fixed beat) or to
## the height it was last hit. Reinforcements march in from the far door and queue up.

## Slack on the fight distance within which a guard starts its attacks.
const ATTACK_SLACK := 0.25


static func create(
	cfg: RaidConfig, layout: RaidLayout, skill: int, rng: RandomNumberGenerator
) -> Array[RaidFighter]:
	var guards: Array[RaidFighter] = []
	for post: float in layout.posts:
		guards.append(make_guard(cfg, skill, post, rng, false))
	return guards


## The seed only picks where in its patterns each guard starts.
static func make_guard(
	cfg: RaidConfig, skill: int, x: float, rng: RandomNumberGenerator, reinforcement: bool
) -> RaidFighter:
	var rules := cfg.guard_skills[skill]
	var guard := RaidFighter.new()
	guard.x = x
	guard.post_x = x
	guard.skill = skill
	guard.health = rules.health
	guard.max_health = rules.health
	guard.reinforcement = reinforcement
	guard.attack_index = rng.randi_range(0, rules.attacks.size() - 1)
	guard.stance_index = rng.randi_range(0, rules.stances.size() - 1)
	guard.react_index = rng.randi_range(0, rules.reacts.size() - 1)
	guard.stance = rules.stances[guard.stance_index]
	guard.start(RaidFighter.Action.READY if reinforcement else RaidFighter.Action.POST)
	return guard


## Picks the guard the leader faces and wakes it when the leader comes within sight.
static func update_front(state: RaidState, cfg: RaidConfig) -> void:
	var leader := state.leader
	state.front = -1
	var nearest := INF
	for i: int in state.guards.size():
		var guard := state.guards[i]
		if guard.is_active() and guard.x >= leader.x - 0.01 and guard.x < nearest:
			nearest = guard.x
			state.front = i
	var was_engaged := state.engaged
	state.engaged = (
		state.front >= 0
		and not state.is_sneaking()
		and nearest - leader.x <= cfg.engage_distance
	)
	if not state.engaged:
		return
	var front := state.guards[state.front]
	if front.action == RaidFighter.Action.POST:
		front.start(RaidFighter.Action.READY)
		front.idle_ticks = 0
	if not was_engaged:
		state.events.append(RaidEvent.new(RaidEvent.Kind.ENGAGE, state.front))


## Awake guards walk towards the leader, each stopping a queue gap behind the one before it;
## while the leader sneaks they wait beyond the end of his path.
static func move(state: RaidState, cfg: RaidConfig, layout: RaidLayout) -> void:
	var dt := 1.0 / cfg.tick_rate
	var order: Array[RaidFighter] = []
	for guard: RaidFighter in state.guards:
		if guard.is_active() and guard.x >= state.leader.x - 0.01:
			order.append(guard)
	order.sort_custom(func(a: RaidFighter, b: RaidFighter) -> bool: return a.x < b.x)
	var limit := state.leader.x + cfg.fight_distance
	if state.is_sneaking():
		limit = maxf(limit, layout.sneak_paths[state.sneak_path].to_x + cfg.fight_distance)
	var step := cfg.guard_speed * dt
	for guard: RaidFighter in order:
		if guard.action == RaidFighter.Action.READY:
			if guard.x > limit:
				guard.x = maxf(limit, guard.x - step)
			elif state.is_sneaking():
				guard.x = minf(limit, guard.x + step)
		limit = guard.x + cfg.queue_gap


## Stances, reactions and attacks of every awake guard; only the front guard attacks.
static func think(state: RaidState, cfg: RaidConfig) -> void:
	var leader := state.leader
	for i: int in state.guards.size():
		var guard := state.guards[i]
		if guard.action != RaidFighter.Action.READY or not guard.is_active():
			continue
		var rules := cfg.guard_skills[guard.skill]
		guard.stance_ticks += 1
		if guard.stance_ticks >= cfg.ticks(rules.stance_ms):
			guard.stance_index = (guard.stance_index + 1) % rules.stances.size()
			guard.stance = rules.stances[guard.stance_index]
			guard.stance_ticks = 0
		if guard.react_in > 0:
			guard.react_in -= 1
			if guard.react_in == 0:
				guard.stance = guard.react_height
				guard.stance_ticks = 0
				guard.react_in = -1
		var in_reach := guard.x - leader.x <= cfg.fight_distance + ATTACK_SLACK
		if i != state.front or not state.engaged or not in_reach or leader.is_down():
			continue
		guard.idle_ticks += 1
		if guard.idle_ticks >= cfg.ticks(rules.idle_ms):
			var height := rules.attacks[guard.attack_index]
			guard.attack_index = (guard.attack_index + 1) % rules.attacks.size()
			guard.idle_ticks = 0
			guard.react_in = -1
			guard.start(RaidFighter.Action.WINDUP, cfg.ticks(rules.windup_ms), height)
			state.events.append(RaidEvent.new(RaidEvent.Kind.STRIKE, i, height))


## The leader starts a blow at `height`: a ready guard whose pattern says so turns its guard
## there after its reaction time.
static func react(guard: RaidFighter, cfg: RaidConfig, height: int) -> void:
	var rules := cfg.guard_skills[guard.skill]
	if guard.action != RaidFighter.Action.READY or rules.react_ms <= 0.0:
		return
	if rules.reacts[guard.react_index]:
		guard.react_in = cfg.ticks(rules.react_ms)
		guard.react_height = height
	guard.react_index = (guard.react_index + 1) % rules.reacts.size()
