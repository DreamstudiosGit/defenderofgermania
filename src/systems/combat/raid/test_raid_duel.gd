extends GutTest
## Sword fight of the castle raid: parry window, blocks and counters, ripostes and stamina.

const SEED := 1198
const HIGH := RaidFighter.Height.HIGH
const MID := RaidFighter.Height.MID
const LOW := RaidFighter.Height.LOW

var _cfg: RaidConfig


func before_each() -> void:
	_cfg = RaidConfig.load_file()


func test_parry_holds_up_to_150_plus_20_blade_ms_before_the_blow() -> void:
	# Blade 2: 190 ms, a parry 5 ticks (167 ms) old still holds, 6 ticks (200 ms) is too early.
	var hold := _cfg.parry_ticks(2) - 1
	assert_eq(hold, 5)
	assert_eq(_parry_at(hold, true), RaidEvent.Kind.PARRIED)
	assert_eq(_parry_at(hold + 1, true), RaidEvent.Kind.HIT)
	assert_eq(_parry_at(0, true), RaidEvent.Kind.PARRIED, "a parry on the last tick still holds")
	assert_eq(_parry_at(2, false), RaidEvent.Kind.HIT, "a parry at the wrong height fails")


func test_a_parried_guard_stands_open_for_the_riposte() -> void:
	var sim := _engage(0)
	_wait_for_windup(sim)
	var guard := sim.state.front_guard()
	_step_until_age(sim, guard, 2)
	var parry := RaidInput.new()
	parry.parry = guard.height
	sim.step(parry)
	_step_until_event(sim, RaidEvent.Kind.PARRIED)
	assert_eq(guard.action, RaidFighter.Action.OPEN)
	assert_eq(sim.state.leader.action, RaidFighter.Action.READY, "the leader may strike at once")
	var health := guard.health
	var strike := RaidInput.new()
	strike.strike = guard.stance
	sim.step(strike)
	_step_until_event(sim, RaidEvent.Kind.HIT)
	var expected := health - _cfg.strike_damage_for(2)
	assert_almost_eq(guard.health, expected, 1e-6, "an open guard cannot block")
	assert_eq(guard.action, RaidFighter.Action.STAGGER)


func test_a_guard_blocks_its_stance_and_strikes_back_at_once() -> void:
	var sim := _engage(0)
	var guard := sim.state.front_guard()
	_wait_until_ready(sim, guard)
	var strike := RaidInput.new()
	strike.strike = guard.stance
	sim.step(strike)
	var blocked := _step_until_event(sim, RaidEvent.Kind.BLOCKED)
	assert_not_null(blocked)
	assert_eq(guard.health, guard.max_health)
	sim.step(RaidInput.new())
	assert_eq(guard.action, RaidFighter.Action.WINDUP, "a block is the guard's cue")
	assert_eq(sim.state.leader.action, RaidFighter.Action.RECOVER)
	assert_gt(
		guard.ticks_left(), sim.state.leader.ticks_left() + 2,
		"the counter can still be parried after the recovery"
	)


func test_an_uncovered_height_hits_and_a_skilled_guard_learns_it() -> void:
	var sim := _engage(1)
	var guard := sim.state.front_guard()
	_wait_until_ready(sim, guard)
	# Skill 1 turns its guard only on every third blow (reacts: false, false, true).
	guard.react_index = 0
	var open := (guard.stance + 1) % 3
	var strike := RaidInput.new()
	strike.strike = open
	sim.step(strike)
	assert_eq(_step_until_any(sim, [RaidEvent.Kind.HIT, RaidEvent.Kind.BLOCKED]), RaidEvent.Kind.HIT)
	assert_eq(guard.stance, open, "skill 1 adapts its guard to the last hit")


func test_stamina_limits_strikes() -> void:
	var sim := RaidSim.new(_cfg, _setup(1), SEED)
	var strikes := 0
	var tired := false
	for i: int in 90:
		var input := RaidInput.new()
		input.strike = MID
		sim.step(input)
		assert_true(sim.state.leader.stamina >= 0.0)
		for event: RaidEvent in sim.state.events:
			if event.kind == RaidEvent.Kind.STRIKE and event.fighter == RaidEvent.LEADER:
				strikes += 1
			tired = tired or event.kind == RaidEvent.Kind.TIRED
	assert_eq(strikes, 4, "100 stamina pays four blows of 24 in a row")
	assert_true(tired, "the fifth blow is refused")
	for i: int in 60:
		sim.step(RaidInput.new())
	var again := RaidInput.new()
	again.strike = HIGH
	sim.step(again)
	assert_eq(sim.state.leader.action, RaidFighter.Action.WINDUP, "rested, he strikes again")


func test_a_parry_costs_less_stamina_than_a_blow() -> void:
	var sim := RaidSim.new(_cfg, _setup(1), SEED)
	var input := RaidInput.new()
	input.parry = LOW
	sim.step(input)
	assert_eq(sim.state.leader.action, RaidFighter.Action.PARRY)
	assert_eq(sim.state.leader.stamina, _cfg.stamina - _cfg.parry_cost)
	assert_lt(_cfg.parry_cost, _cfg.strike_cost)


func _setup(guard_skill: int) -> RaidSetup:
	var setup := RaidSetup.new()
	setup.guard_skill = guard_skill
	setup.castle_level = 2
	setup.blade = 2
	return setup


## Walks to the first guard until it stands within reach.
func _engage(guard_skill: int) -> RaidSim:
	var sim := RaidSim.new(_cfg, _setup(guard_skill), SEED)
	var walk := RaidInput.new()
	walk.move = 1.0
	while not sim.state.engaged and sim.state.tick < 600:
		sim.step(walk)
	var guard := sim.state.front_guard()
	while guard.x - sim.state.leader.x > _cfg.fight_distance + 0.01 and sim.state.tick < 900:
		sim.step(walk)
	assert_true(sim.state.engaged)
	return sim


## Steps until the front guard has just become ready again, far from its next blow.
func _wait_until_ready(sim: RaidSim, guard: RaidFighter) -> void:
	for i: int in 300:
		if guard.action == RaidFighter.Action.READY and guard.idle_ticks <= 5:
			return
		sim.step(RaidInput.new())
	fail_test("the guard never became ready")


func _wait_for_windup(sim: RaidSim) -> void:
	for i: int in 300:
		if sim.state.front_guard().action == RaidFighter.Action.WINDUP:
			return
		sim.step(RaidInput.new())
	fail_test("the guard never attacked")


## Steps until a parry pressed in the next step would be `age` ticks old when the blow lands.
func _step_until_age(sim: RaidSim, guard: RaidFighter, age: int) -> void:
	while guard.ticks_left() - 1 > age:
		sim.step(RaidInput.new())


func _parry_at(age: int, right_height: bool) -> int:
	var sim := _engage(0)
	_wait_for_windup(sim)
	var guard := sim.state.front_guard()
	_step_until_age(sim, guard, age)
	var parry := RaidInput.new()
	parry.parry = guard.height if right_height else (guard.height + 1) % 3
	sim.step(parry)
	return _step_until_any(sim, [RaidEvent.Kind.PARRIED, RaidEvent.Kind.HIT])


func _step_until_event(sim: RaidSim, kind: RaidEvent.Kind) -> RaidEvent:
	for i: int in 120:
		for event: RaidEvent in sim.state.events:
			if event.kind == kind:
				return event
		sim.step(RaidInput.new())
	return null


## The first of `kinds` in this or a later tick; -1 if none comes within 4 s.
func _step_until_any(sim: RaidSim, kinds: Array) -> int:
	for i: int in 120:
		for event: RaidEvent in sim.state.events:
			if event.kind in kinds:
				return event.kind
		sim.step(RaidInput.new())
	return -1
