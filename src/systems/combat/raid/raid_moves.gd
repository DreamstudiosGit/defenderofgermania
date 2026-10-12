class_name RaidMoves
extends RefCounted
## The leader's way through the castle: walking (never past a standing guard), sneak paths that
## bypass a guard at its post but take longer, and the deed in the target room.

## How far before the deed spot the leader may start the deed.
const DEED_REACH := 0.6
const END_MARGIN := 0.5


static func update(
	state: RaidState, cfg: RaidConfig, layout: RaidLayout, setup: RaidSetup, input: RaidInput
) -> void:
	var leader := state.leader
	var dt := 1.0 / cfg.tick_rate
	if state.is_sneaking():
		_sneak(state, cfg, layout, input, dt)
		return
	if leader.action != RaidFighter.Action.READY:
		return
	if input.act and not state.engaged:
		var path := layout.entrance_at(leader.x)
		if path >= 0 and path_open(state, layout, path):
			state.sneak_path = path
			state.sneak_progress = 0.0
			state.events.append(RaidEvent.new(RaidEvent.Kind.SNEAK_IN, layout.sneak_paths[path].post))
			return
		if leader.x >= layout.deed_x - DEED_REACH:
			_deed(state, cfg, setup, dt)
			return
	var step := input.move * cfg.walk_speed * dt
	if step > 0.0:
		var limit := layout.end_x - END_MARGIN
		var guard := state.front_guard()
		if guard != null:
			limit = minf(limit, guard.x - cfg.fight_distance)
		leader.x = minf(leader.x + step, maxf(limit, leader.x))
	elif step < 0.0:
		leader.x = maxf(leader.x + step, 0.0)


## A sneak path only helps while its guard still stands unaware at its post.
static func path_open(state: RaidState, layout: RaidLayout, path: int) -> bool:
	var guard := state.guards[layout.sneak_paths[path].post]
	return guard.action == RaidFighter.Action.POST and guard.is_active()


static func _sneak(
	state: RaidState, cfg: RaidConfig, layout: RaidLayout, input: RaidInput, dt: float
) -> void:
	var path := layout.sneak_paths[state.sneak_path]
	state.sneak_progress += input.move * dt / cfg.layout.sneak_seconds
	if state.sneak_progress <= 0.0 and input.move < 0.0:
		state.sneak_progress = 0.0
		state.sneak_path = -1
		state.leader.x = path.from_x
		state.events.append(RaidEvent.new(RaidEvent.Kind.SNEAK_OUT, path.post))
		return
	state.sneak_progress = maxf(state.sneak_progress, 0.0)
	if state.sneak_progress < 1.0:
		return
	state.sneak_path = -1
	state.sneak_progress = 0.0
	state.leader.x = path.to_x
	for guard: RaidFighter in state.guards:
		if not guard.is_active() or guard.x >= path.to_x:
			continue
		if guard.action == RaidFighter.Action.POST:
			guard.avoided = true
		else:
			guard.x = path.to_x + cfg.fight_distance
	state.events.append(RaidEvent.new(RaidEvent.Kind.SNEAK_OUT, path.post))


static func _deed(state: RaidState, cfg: RaidConfig, setup: RaidSetup, dt: float) -> void:
	if state.deed_progress <= 0.0:
		state.events.append(RaidEvent.new(RaidEvent.Kind.DEED_START))
	state.deed_progress += dt / cfg.targets[setup.target].deed_seconds
	if state.deed_progress >= 1.0:
		state.deed_progress = 1.0
		state.events.append(RaidEvent.new(RaidEvent.Kind.DEED_DONE))
