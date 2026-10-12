class_name RaidFigures
extends Node3D
## Shows the leader and the guards: places them on the corridor or on a sneak path, turns them
## towards each other and picks each one's clip from its simulated action, so wind-ups, contact
## frames and parries line up with the simulation's ticks.

const HEIGHT_NAMES: Array[String] = ["high", "mid", "low"]
const STANCE_CLIPS: Array[StringName] = [&"guard_high", &"idle", &"guard_low"]
const WALKING := 0.25
## A parry that held stays in its pose this long before the fighter settles.
const PARRY_AFTERGLOW := 0.3
const DOOR_WALK := 1.6

var leader: RaidFigure
var guards: Array[RaidFigure] = []

var _cfg: RaidConfig
var _world: RaidWorld
var _defender: String
var _defender_colors := PackedColorArray()
var _turn: float
var _swing_ticks: float
var _contact: float
var _parry_hold: float
var _down_z: float
## Per figure (leader first): the action shown last, the one before it, loop clock, fall clock.
var _shown: Array[int] = []
var _before: Array[int] = []
var _clock := PackedFloat64Array()
var _since := PackedFloat64Array()
var _fallen := PackedFloat64Array()
var _last_x := PackedFloat64Array()


func setup(
	cfg: RaidConfig, world: RaidWorld, state: RaidState, raider: String,
	raider_colors: PackedColorArray, defender: String, defender_colors: PackedColorArray
) -> void:
	_cfg = cfg
	_world = world
	_defender = defender
	_defender_colors = defender_colors
	_turn = deg_to_rad(RaidArt.number("figures", "turn_deg", 64.0))
	_swing_ticks = RaidArt.number("figures", "swing_ticks", 4.0)
	_contact = RaidArt.number("figures", "strike_contact", 0.125)
	_parry_hold = RaidArt.number("figures", "parry_hold", 0.375)
	_down_z = RaidArt.number("figures", "down_z", -0.7)
	leader = RaidFigure.new()
	add_child(leader)
	leader.build("raider", raider, raider_colors)
	leader.rotation.y = _turn
	_track(state.leader.x)
	for guard: RaidFighter in state.guards:
		add_guard(guard)


func add_guard(guard: RaidFighter) -> void:
	var figure := RaidFigure.new()
	add_child(figure)
	var crest: bool = RaidArt.section("figures").get("guard_crest", false) == true
	figure.build("guard", _defender if crest else "", _defender_colors)
	# Mirror image of the leader's stance: facing left with the sword arm towards the camera.
	figure.basis = Basis.from_scale(Vector3(-1.0, 1.0, 1.0)) * Basis(Vector3.UP, _turn)
	guards.append(figure)
	_track(guard.x)


## Places and poses every figure; alpha interpolates between the last two ticks (previous holds
## the corridor positions of the tick before, leader first, then the sneak progress).
func update_view(sim: RaidSim, previous: PackedFloat64Array, alpha: float, delta: float) -> void:
	var state := sim.state
	var leader_x := _lerp_x(previous, 0, state.leader.x, alpha)
	var at := Vector3(leader_x, _world.floor_y(leader_x), RaidWorld.LANE_Z)
	if state.is_sneaking():
		var before := previous[previous.size() - 1] if not previous.is_empty() else -1.0
		var progress := state.sneak_progress
		if before >= 0.0:
			progress = lerpf(before, progress, alpha)
		at = _world.sneak_point(state.sneak_path, progress)
	_place(0, leader, at, delta)
	_pose_leader(sim, alpha, delta)
	for i: int in state.guards.size():
		if i >= guards.size():
			add_guard(state.guards[i])
		var guard := state.guards[i]
		var x := _lerp_x(previous, i + 1, guard.x, alpha)
		var z := RaidWorld.LANE_Z
		if guard.reinforcement:
			var out := clampf((sim.layout.end_x - x) / DOOR_WALK, 0.0, 1.0)
			z = lerpf(_world.back_z + 0.8, RaidWorld.LANE_Z, out)
		if guard.is_down():
			z = lerpf(z, _down_z, minf(_fallen[i + 1], 1.0))
		_place(i + 1, guards[i], Vector3(x, _world.floor_y(x), z), delta)
		_pose_fighter(i + 1, guards[i], guard, alpha, delta, true)


## Screen-space top and bottom of the leader, for aiming with the mouse.
func leader_span(camera: Camera3D) -> Vector2:
	var feet := camera.unproject_position(leader.global_position)
	var head := camera.unproject_position(leader.global_position + Vector3.UP * 1.95)
	return Vector2(head.y, feet.y)


func _track(x: float) -> void:
	_shown.append(-1)
	_before.append(-1)
	_clock.append(0.0)
	_since.append(0.0)
	_fallen.append(0.0)
	_last_x.append(x)


func _lerp_x(previous: PackedFloat64Array, slot: int, current: float, alpha: float) -> float:
	return lerpf(previous[slot], current, alpha) if slot < previous.size() - 1 else current


func _place(slot: int, figure: RaidFigure, at: Vector3, delta: float) -> void:
	var speed := absf(at.x - _last_x[slot]) / maxf(delta, 1e-4)
	_last_x[slot] = at.x
	figure.position = at
	figure.set_meta("speed", speed)


func _pose_leader(sim: RaidSim, alpha: float, delta: float) -> void:
	var state := sim.state
	if state.over and state.outcome == RaidResult.Outcome.SUCCESS:
		_clock[0] += delta
		leader.pose(&"cheer", _clock[0], true)
		return
	if state.is_sneaking():
		var speed: float = leader.get_meta("speed", 0.0)
		_clock[0] += delta * (1.0 if speed > 0.05 else 0.0)
		leader.pose(&"sneak", _clock[0], true)
		return
	var standing := state.leader.action == RaidFighter.Action.READY
	if state.deed_progress > 0.0 and not state.engaged and standing:
		var speed: float = leader.get_meta("speed", 0.0)
		if speed < WALKING:
			_clock[0] += delta
			leader.pose(&"deed", _clock[0], true)
			return
	_pose_fighter(0, leader, state.leader, alpha, delta, false)


func _pose_fighter(
	slot: int, figure: RaidFigure, fighter: RaidFighter, alpha: float, delta: float, guard: bool
) -> void:
	_since[slot] += delta
	if fighter.action != _shown[slot]:
		_before[slot] = _shown[slot]
		_shown[slot] = fighter.action
		_since[slot] = 0.0
	var height := HEIGHT_NAMES[clampi(fighter.height, 0, 2)]
	var tick := 1.0 / _cfg.tick_rate
	var animator := figure.animator
	if animator == null:
		return
	match fighter.action:
		RaidFighter.Action.WINDUP:
			var left := float(fighter.ticks_left()) - alpha
			if left > _swing_ticks:
				var raise := maxf(1.0, fighter.action_length - _swing_ticks)
				var share := (fighter.action_ticks + alpha) / raise
				figure.pose(
					StringName("windup_" + height), share * animator.clip_length("windup_" + height)
				)
			else:
				figure.pose(
					StringName("strike_" + height), (_swing_ticks - left) / _swing_ticks * _contact
				)
		RaidFighter.Action.RECOVER:
			var share := (fighter.action_ticks + alpha) / maxf(1.0, fighter.action_length)
			if _before[slot] == RaidFighter.Action.PARRY:
				var length := animator.clip_length("parry_" + height)
				figure.pose(StringName("parry_" + height), lerpf(_parry_hold, length, share))
			else:
				var length := animator.clip_length("strike_" + height)
				figure.pose(StringName("strike_" + height), lerpf(_contact, length, share))
		RaidFighter.Action.PARRY:
			figure.pose(
				StringName("parry_" + height),
				minf((fighter.action_ticks + alpha) * tick, _parry_hold)
			)
		RaidFighter.Action.OPEN, RaidFighter.Action.STAGGER:
			var share := (fighter.action_ticks + alpha) / maxf(1.0, fighter.action_length)
			figure.pose(&"hit", share * animator.clip_length("hit"))
		RaidFighter.Action.DOWN:
			_fallen[slot] += delta
			figure.pose(&"down", _fallen[slot])
		_:
			var speed: float = figure.get_meta("speed", 0.0)
			var parried := _before[slot] == RaidFighter.Action.PARRY
			if parried and _since[slot] < PARRY_AFTERGLOW:
				var length := animator.clip_length("parry_" + height)
				var share := _since[slot] / PARRY_AFTERGLOW
				figure.pose(StringName("parry_" + height), lerpf(_parry_hold, length, share))
			elif speed > WALKING:
				_clock[slot] += delta * speed / _cfg.walk_speed
				figure.pose(&"walk", _clock[slot], true)
			elif guard:
				_clock[slot] += delta
				figure.pose(STANCE_CLIPS[clampi(fighter.stance, 0, 2)], _clock[slot], true)
			else:
				_clock[slot] += delta
				figure.pose(&"idle", _clock[slot], true)
