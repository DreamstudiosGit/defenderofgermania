class_name JoustAI
extends RefCounted
## Computer rider for either side of a joust. It rides like a human through JoustInputs but
## plays its skill's fixed error pattern (JoustAIProfile): no dice, the seed only picks where in
## each repeating list it starts.

var rider: int
var profile: JoustAIProfile

var _offset: int


func _init(rider_index: int, error_pattern: JoustAIProfile, seed_value: int) -> void:
	rider = rider_index
	profile = error_pattern
	_offset = posmod(seed_value * 7 + rider_index * 5, 1 << 20)


static func for_skill(cfg: JoustConfig, rider_index: int, skill: int, seed_value: int) -> JoustAI:
	return JoustAI.new(rider_index, cfg.ai[clampi(skill, 0, cfg.ai.size() - 1)], seed_value)


func think(sim: JoustSim) -> JoustInput:
	var input := JoustInput.new()
	var state := sim.state
	var cfg := sim.cfg
	var start := sim.pass_time()
	var tick := sim.pass_tick()
	var dt := sim.tick_seconds()
	var pass_index := maxi(state.pass_count - 1, 0)
	input.aim = cfg.aim_rest / cfg.aim_range
	match state.phase:
		JoustState.Phase.RUNUP:
			var spurs := profile.spurs.size()
			for i: int in spurs:
				var nth := _index(i + pass_index * spurs, profile.spur_error_ms.size())
				var at := sim.beat_time(profile.spurs[i]) + profile.spur_error_ms[nth] / 1000.0
				var fraction := _fraction(at, tick, dt)
				if fraction >= 0.0:
					input.spur = fraction
		JoustState.Phase.AIM, JoustState.Phase.CLASH:
			if start >= sim.aim_start_time() + profile.reaction_seconds:
				input.aim = _aim(sim, pass_index)
				input.shield = _shield(sim, pass_index)
			var error := profile.strike_error_ms[_index(pass_index, profile.strike_error_ms.size())]
			input.strike = _fraction(sim.impact_time() + error / 1000.0, tick, dt)
	return input


## Where the hand goes: the chosen zone, off by the pattern's miss, against part of the sway the
## lance will have at the impact.
func _aim(sim: JoustSim, pass_index: int) -> Vector2:
	var cfg := sim.cfg
	var target := profile.targets[_index(pass_index, profile.targets.size())]
	var zone := cfg.zones[maxi(cfg.zone_ids().find(target), 0)]
	var miss := profile.aim_error[_index(pass_index, profile.aim_error.size())]
	var sway := sim.sway(rider, sim.impact_time()) * profile.sway_compensation
	return (zone.center + miss - sway) / cfg.aim_range


## Turns the shield towards where the opponent's lance points right now, in passes the pattern
## reads it.
func _shield(sim: JoustSim, pass_index: int) -> Vector2:
	if not profile.shield_reads[_index(pass_index, profile.shield_reads.size())]:
		return Vector2.ZERO
	var incoming := sim.state.riders[1 - rider].tip
	return Vector2(-incoming.x, incoming.y).normalized()


func _index(i: int, size: int) -> int:
	return (i + _offset) % size


## Fraction of the pass's tick `tick_index` when a press at `at` seconds into the pass falls
## into it, else no press. Flooring gives every moment exactly one tick.
static func _fraction(at: float, tick_index: int, dt: float) -> float:
	var ticks := at / dt
	if floori(ticks) != tick_index:
		return JoustInput.NO_PRESS
	return ticks - tick_index
