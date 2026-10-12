class_name MerchantAI
extends RefCounted
## The computer raider (auto-resolve, a computer house, tests): rides for the nearest rolling
## wagon, cuts the harness ahead with the crossbow, pulls drivers, parries and fights escorts —
## with the fixed mistakes of its skill (data raider_ai): slow decisions, parries off by a
## repeating list of milliseconds, bolts loosed while the aim still sways, pauses. No random
## numbers: the same raid plays the same way.

var skill: MerchantConfig.RaiderSkill

var _target_wagon: int = -1
var _next_think: int = 0
var _parry_attempts: int = 0
var _last_escort_state := PackedInt32Array()
## Per escort: seconds before his blow at which this attempt presses parry, or -INF once done.
var _parry_at := PackedFloat64Array()


func _init(config: MerchantConfig, skill_level: int) -> void:
	skill = config.raider_skill(skill_level)


func think(sim: MerchantSim) -> MerchantInput:
	var input := MerchantInput.new()
	var s := sim.state
	if s.phase != MerchantState.Phase.RAID or s.captured or _hesitating(sim):
		return input
	if _parry(sim, input):
		return input
	if s.tick >= _next_think:
		_next_think = s.tick + maxi(1, roundi(skill.think_seconds * sim.tick_rate))
		_target_wagon = _nearest_rolling(sim)
	if skill.fights_escorts and _fight(sim, input):
		return input
	if s.reload <= 0.0 and s.bolts > 0 and s.pull_wagon < 0 and sim.crossbow_target() >= 0:
		input.shoot = absf(sim.sway()) <= sim.cfg.hit_window * skill.aim_factor
	if sim.pull_target() >= 0:
		input.pull = true
		return input
	if _target_wagon >= 0:
		input.move = signf(sim.box_x(_target_wagon) - s.leader_x)
	return input


func _hesitating(sim: MerchantSim) -> bool:
	if skill.hesitate_every_seconds <= 0.0 or skill.hesitate_seconds <= 0.0:
		return false
	var cycle := skill.hesitate_every_seconds + skill.hesitate_seconds
	return fmod(sim.raid_seconds(), cycle) >= skill.hesitate_every_seconds


## Presses parry once per escort wind-up, off by the next error of the skill's list.
func _parry(sim: MerchantSim, input: MerchantInput) -> bool:
	var s := sim.state
	_last_escort_state.resize(s.escort_count())
	_parry_at.resize(s.escort_count())
	var press := false
	for e: int in s.escort_count():
		var winding := s.escort_state[e] == MerchantState.Escort.WINDUP
		if winding and _last_escort_state[e] != MerchantState.Escort.WINDUP:
			var errors := skill.parry_errors_ms
			var error := errors[_parry_attempts % errors.size()] / 1000.0
			_parry_attempts += 1
			_parry_at[e] = sim.parry_window() * 0.5 + error
		_last_escort_state[e] = s.escort_state[e]
		var aimed_at_leader := s.escort_target[e] == MerchantState.LEADER
		if winding and aimed_at_leader and s.escort_timer[e] <= _parry_at[e]:
			_parry_at[e] = -INF
			press = s.parry_cooldown <= 0.0
	input.parry = press
	return press


## Stands up to escorts who go for the leader: waits out the shield, strikes when they are open.
func _fight(sim: MerchantSim, input: MerchantInput) -> bool:
	var s := sim.state
	var foe := -1
	var nearest := sim.cfg.strike_reach + sim.cfg.escort_reach
	for e: int in s.escort_count():
		var distance := absf(s.escort_x[e] - s.leader_x)
		var fighting := s.escort_state[e] >= MerchantState.Escort.COVER
		fighting = fighting and s.escort_state[e] <= MerchantState.Escort.STAGGERED
		if fighting and s.escort_target[e] == MerchantState.LEADER and distance <= nearest:
			foe = e
			nearest = distance
	if foe < 0:
		return false
	var open := not MerchantEscorts.guarded(s, foe)
	if nearest > sim.cfg.strike_reach * 0.8:
		input.move = signf(s.escort_x[foe] - s.leader_x)
	input.strike = open and nearest <= sim.cfg.strike_reach and s.strike_cooldown <= 0.0
	return true


func _nearest_rolling(sim: MerchantSim) -> int:
	var s := sim.state
	var best := -1
	var nearest := INF
	for w: int in s.wagon_count():
		var distance := absf(sim.box_x(w) - s.leader_x)
		if s.is_rolling(w) and distance < nearest:
			best = w
			nearest = distance
	return best
