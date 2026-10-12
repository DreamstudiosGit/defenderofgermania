class_name RaidAI
extends RefCounted
## The computer leader, for auto-resolve and tests. It walks on, takes sneak paths on a fixed
## beat and parries with a fixed error pattern per skill (ok, late, early, wrong height). Skilled
## leaders read the guard's stance and timing and riposte after a parry; unskilled ones strike
## blindly. No dice: the seed only picks where each pattern starts.

const OK := 0
const LATE := 1
const EARLY := 2
const WRONG := 3
## An early parry is pressed this many ticks before the window opens.
const EARLY_TICKS := 3
const STEP_SLACK := 0.1

var skill: RaidRules.AiSkill

var _parry_index: int
var _strike_index: int
var _sneak_index: int
var _planned_windup := Vector2i(-1, -1)
var _plan: int = OK
var _sneak_choices: Dictionary[int, bool] = {}


## `pattern` replaces the skill's data pattern (scripted leaders in tests).
func _init(
	cfg: RaidConfig, ai_skill: int, seed_value: int, pattern: RaidRules.AiSkill = null
) -> void:
	skill = pattern if pattern != null else cfg.ai_skills[clampi(ai_skill, 0, RaidConfig.SKILLS - 1)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_parry_index = rng.randi_range(0, skill.parries.size() - 1)
	_strike_index = rng.randi_range(0, skill.strikes.size() - 1)
	_sneak_index = rng.randi_range(0, skill.sneaks.size() - 1)


## Plays a whole raid with the computer leader.
static func auto_resolve(
	cfg: RaidConfig, setup: RaidSetup, seed_value: int, ai_skill: int
) -> RaidResult:
	var sim := RaidSim.new(cfg, setup, seed_value)
	var ai := RaidAI.new(cfg, ai_skill, seed_value)
	while not sim.is_over():
		sim.step(ai.think(sim))
	return sim.result()


func think(sim: RaidSim) -> RaidInput:
	var input := RaidInput.new()
	var state := sim.state
	if state.over:
		return input
	if state.is_sneaking():
		input.move = 1.0
		return input
	if state.engaged:
		_fight(sim, input)
		return input
	var leader := state.leader
	var path := sim.layout.entrance_at(leader.x)
	if path >= 0 and RaidMoves.path_open(state, sim.layout, path) and _wants_sneak(path):
		input.act = true
	elif leader.x >= sim.layout.deed_x - RaidMoves.DEED_REACH * 0.5:
		input.act = true
	else:
		input.move = 1.0
	return input


func _wants_sneak(path: int) -> bool:
	if not _sneak_choices.has(path):
		_sneak_choices[path] = skill.sneaks[_sneak_index]
		_sneak_index = (_sneak_index + 1) % skill.sneaks.size()
	return _sneak_choices[path]


func _fight(sim: RaidSim, input: RaidInput) -> void:
	var state := sim.state
	var cfg := sim.cfg
	var guard := state.front_guard()
	if guard.x - state.leader.x > cfg.fight_distance + STEP_SLACK:
		input.move = 1.0
	if state.leader.action != RaidFighter.Action.READY:
		return
	match guard.action:
		RaidFighter.Action.WINDUP:
			_parry(sim, guard, input)
			if input.parry < 0 and not skill.reads_stance:
				_strike(sim, guard, input)
		RaidFighter.Action.OPEN:
			if skill.riposte or not skill.reads_stance:
				_strike(sim, guard, input)
		RaidFighter.Action.READY:
			_strike(sim, guard, input)
		_:
			if not skill.reads_stance:
				_strike(sim, guard, input)


## Parries the guard's blow on the beat of the error pattern; one plan per blow.
func _parry(sim: RaidSim, guard: RaidFighter, input: RaidInput) -> void:
	var windup := Vector2i(sim.state.front, sim.state.tick - guard.action_ticks)
	if windup != _planned_windup:
		_planned_windup = windup
		_plan = skill.parries[_parry_index]
		_parry_index = (_parry_index + 1) % skill.parries.size()
	var hold := sim.cfg.parry_ticks(sim.setup.blade) - 1
	# The parry pressed in the next step is (ticks_left - 1) ticks old when the blow lands.
	var age := guard.ticks_left() - 1
	match _plan:
		OK:
			if age <= hold / 2:
				input.parry = guard.height
		WRONG:
			if age <= hold / 2:
				input.parry = (guard.height + 1) % RaidRules.HEIGHTS.size()
		EARLY:
			if age <= hold + EARLY_TICKS:
				input.parry = guard.height


## Skilled leaders strike an uncovered height when the guard cannot answer in time; unskilled
## ones swing their pattern whenever they have the stamina.
func _strike(sim: RaidSim, guard: RaidFighter, input: RaidInput) -> void:
	var cfg := sim.cfg
	var leader := sim.state.leader
	var reserve := cfg.parry_cost if skill.reads_stance else 0.0
	if leader.stamina < cfg.strike_cost + reserve or guard.x - leader.x > cfg.reach:
		return
	var height := skill.strikes[_strike_index]
	if skill.reads_stance and guard.action == RaidFighter.Action.READY:
		var rules := cfg.guard_skills[guard.skill]
		var idle_left := cfg.ticks(rules.idle_ms) - guard.idle_ticks
		var busy := cfg.ticks(cfg.strike_windup_ms) + cfg.ticks(cfg.strike_recover_ms) + 2
		if idle_left < busy:
			return
		for _i: int in skill.strikes.size():
			if height != guard.stance:
				break
			_strike_index = (_strike_index + 1) % skill.strikes.size()
			height = skill.strikes[_strike_index]
	_strike_index = (_strike_index + 1) % skill.strikes.size()
	input.strike = height
