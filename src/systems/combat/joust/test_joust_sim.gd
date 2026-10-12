extends GutTest
## Joust rules driven by scripted riders: timing, zones, tempo, shield, falls, draws, replays.

const EPSILON := 1e-6
const HELMET := Vector2(0.0, 0.5)
const RIM := Vector2(0.4, 0.15)

var _cfg: JoustConfig


class Scripted:
	var rider: int
	var spur_beats: Array = [0, 1, 2, 3]
	## Seconds off each beat.
	var spur_error: float = 0.0
	## Where the tip should be at the impact; the hand steers against the sway.
	var target := Vector2(0.0, 0.5)
	var aim: bool = true
	## Seconds from the impact to the couching press; NAN never couches.
	var strike_offset: float = 0.0
	var extra_strikes: Array = []
	var shield := Vector2.ZERO

	func _init(rider_index: int) -> void:
		rider = rider_index

	func input(sim: JoustSim) -> JoustInput:
		var input := JoustInput.new()
		var tick := sim.pass_tick()
		var dt := sim.tick_seconds()
		input.aim = sim.cfg.aim_rest / sim.cfg.aim_range
		input.shield = shield
		if sim.state.phase == JoustState.Phase.RUNUP:
			for beat: int in spur_beats:
				input.spur = maxf(input.spur, JoustAI._fraction(
					sim.beat_time(beat) + spur_error, tick, dt
				))
		elif sim.state.in_pass():
			if aim:
				var hand := target - sim.sway(rider, sim.impact_time())
				input.aim = hand / sim.cfg.aim_range
			for offset: float in [strike_offset] + extra_strikes:
				if not is_nan(offset):
					var at := JoustAI._fraction(sim.impact_time() + offset, tick, dt)
					input.strike = maxf(input.strike, at)
		return input


func before_each() -> void:
	_cfg = JoustConfig.load_file()


func test_perfect_timing_on_the_helmet_breaks_the_lance_for_six_points() -> void:
	var sim := _sim()
	var attacker := Scripted.new(0)
	_run_pass(sim, attacker, _passive(1))
	var rider := sim.state.riders[0]
	assert_eq(rider.last_zone, 0, "helmet")
	assert_true(rider.last_perfect)
	assert_eq(rider.points, 5 + 1)
	assert_almost_eq(sim.state.riders[1].stance, 60.0, EPSILON, "perfect hit takes 40")


func test_couching_outside_the_window_is_a_normal_hit_for_20() -> void:
	var sim := _sim()
	var attacker := Scripted.new(0)
	attacker.strike_offset = 0.2
	_run_pass(sim, attacker, _passive(1))
	assert_false(sim.state.riders[0].last_perfect)
	assert_true(sim.state.riders[0].last_couched)
	assert_eq(sim.state.riders[0].points, 5)
	assert_almost_eq(sim.state.riders[1].stance, 80.0, EPSILON)


func test_window_widens_with_lance_and_for_the_staufer() -> void:
	for case: Array in [["welfen", 2, false], ["welfen", 4, true], ["staufer", 2, true]]:
		var setup := JoustSetup.new()
		setup.house = case[0]
		setup.lance = case[1]
		var sim := JoustSim.new(_cfg, setup)
		var attacker := Scripted.new(0)
		attacker.strike_offset = -0.115
		_run_pass(sim, attacker, _passive(1))
		assert_eq(sim.state.riders[0].last_perfect, case[2], str(case))


func test_rim_scores_one_and_a_miss_nothing() -> void:
	var sim := _sim()
	var attacker := Scripted.new(0)
	attacker.target = RIM
	var defender := _passive(1)
	defender.aim = true
	defender.target = Vector2(-0.6, -0.5)
	_run_pass(sim, attacker, defender)
	assert_eq(sim.state.riders[0].points, 1 + 1, "rim plus the broken lance")
	assert_eq(sim.state.riders[1].last_zone, -1)
	assert_eq(sim.state.riders[1].points, 0)
	assert_eq(sim.state.riders[0].stance, 100.0, "a miss takes no stance")


func test_an_uncouched_or_early_lance_glances_off() -> void:
	var sim := _sim()
	var early := Scripted.new(0)
	early.strike_offset = -0.6
	var never := Scripted.new(1)
	never.strike_offset = NAN
	_run_pass(sim, early, never)
	for rider: JoustRider in sim.state.riders:
		assert_false(rider.last_couched)
		assert_eq(rider.points, 0)
		assert_eq(rider.stance, 100.0)


func test_only_the_first_press_couches_the_lance() -> void:
	var sim := _sim()
	var masher := Scripted.new(0)
	masher.strike_offset = -0.8
	masher.extra_strikes = [-0.4, 0.0, 0.1]
	_run_pass(sim, masher, _passive(1))
	assert_false(sim.state.riders[0].last_couched, "mashing does not find the window")


func test_aligned_shield_halves_the_hit() -> void:
	var sim := _sim()
	var defender := _passive(1)
	defender.shield = Vector2(0, 1)
	_run_pass(sim, Scripted.new(0), defender)
	assert_true(sim.state.riders[1].last_shielded)
	assert_almost_eq(sim.state.riders[1].stance, 80.0, EPSILON)


func test_shield_turned_the_wrong_way_does_not_help() -> void:
	var sim := _sim()
	var defender := _passive(1)
	defender.shield = Vector2(0, -1)
	_run_pass(sim, Scripted.new(0), defender)
	assert_false(sim.state.riders[1].last_shielded)
	assert_almost_eq(sim.state.riders[1].stance, 60.0, EPSILON)


func test_shield_is_judged_in_the_defenders_own_view() -> void:
	var shield_side := _cfg.zones[1].center
	assert_true(JoustStrike.shield_aligned(_cfg, Vector2(-1, -0.25), shield_side))
	assert_false(JoustStrike.shield_aligned(_cfg, Vector2(1, -0.25), shield_side))
	assert_false(JoustStrike.shield_aligned(_cfg, Vector2(-0.2, -0.05), shield_side), "too slight")


func test_spurring_on_the_beat_builds_tempo_and_off_beat_loses_it() -> void:
	var sim := _sim()
	var steady := Scripted.new(0)
	var sloppy := Scripted.new(1)
	sloppy.spur_error = 0.2
	_run_until(sim, steady, sloppy, JoustState.Phase.AIM)
	assert_almost_eq(sim.state.riders[0].tempo, 1.0, EPSILON)
	assert_almost_eq(sim.state.riders[1].tempo, 0.0, EPSILON)


func test_hitting_slowly_takes_less_stance() -> void:
	var sim := _sim()
	var lazy := Scripted.new(0)
	lazy.spur_beats = []
	_run_pass(sim, lazy, _passive(1))
	var force := JoustStrike.force(_cfg, _cfg.tempo_start)
	assert_almost_eq(force, 0.7, EPSILON)
	assert_almost_eq(sim.state.riders[1].stance, 100.0 - 40.0 * force, EPSILON)


func test_too_fast_makes_the_lance_sway_more() -> void:
	var sim := _sim()
	var eager := Scripted.new(0)
	eager.spur_beats = [0, 1, 2, 3, 4, 5]
	_run_until(sim, eager, Scripted.new(1), JoustState.Phase.AIM)
	assert_gt(sim.state.riders[0].tempo, _cfg.tempo_ideal)
	var calm := sim.sway(1, 0.3).length()
	var wild := sim.sway(0, 0.3).length()
	assert_gt(wild, calm * 1.2)


func test_falling_below_zero_stance_loses_at_once() -> void:
	_cfg.stance = 50.0
	var sim := _sim()
	_play(sim, Scripted.new(0), _passive(1))
	var result := sim.result()
	assert_true(result.won)
	assert_eq(result.unseated, JoustResult.OPPONENT)
	assert_eq(result.decided_by, JoustResult.Decision.UNSEATED)
	assert_eq(result.passes, 2, "no third pass after the fall")
	assert_lt(result.opponent_stance, 0.0)


func test_exactly_zero_stance_still_sits() -> void:
	_cfg.stance = 80.0
	var sim := _sim()
	_play(sim, Scripted.new(0), _passive(1))
	assert_eq(sim.result().unseated, JoustResult.OPPONENT, "-40 in the third pass")
	_cfg.stance = 120.0
	sim = _sim()
	_play(sim, Scripted.new(0), _passive(1))
	assert_eq(sim.state.riders[1].stance, 0.0)
	assert_eq(sim.result().unseated, JoustResult.NONE)


func test_level_joust_rides_a_deciding_pass_then_the_opponent_keeps_the_field() -> void:
	var sim := _sim()
	_play(sim, _passive(0), _passive(1))
	var result := sim.result()
	assert_eq(result.passes, _cfg.passes + _cfg.deciding_passes)
	assert_false(result.won)
	assert_eq(result.decided_by, JoustResult.Decision.STATUS_QUO)


func test_level_points_go_to_the_firmer_seat() -> void:
	var sim := _sim()
	var a := Scripted.new(0)
	a.target = RIM
	a.strike_offset = 0.2
	a.shield = Vector2(-1, 0)
	var b := Scripted.new(1)
	b.target = RIM
	b.strike_offset = 0.2
	_play(sim, a, b)
	var result := sim.result()
	assert_eq(result.player_points, result.opponent_points)
	assert_true(result.won)
	assert_eq(result.decided_by, JoustResult.Decision.STANCE)
	assert_eq(result.passes, 3)


func test_perfect_rider_beats_a_sloppy_one() -> void:
	var sim := _sim()
	var sloppy := Scripted.new(1)
	sloppy.spur_beats = [0, 1, 2, 3, 4, 5]
	sloppy.spur_error = 0.15
	sloppy.target = Vector2(0.3, -0.35)
	sloppy.strike_offset = 0.25
	_play(sim, Scripted.new(0), sloppy)
	var result := sim.result()
	assert_true(result.won)
	assert_gt(result.player_points, result.opponent_points)
	assert_gt(result.player_stance, result.opponent_stance)


func test_same_setup_seed_and_inputs_replay_identically() -> void:
	var setup := JoustSetup.new()
	setup.opponent_skill = 2
	var first := JoustSim.play_out(_cfg, setup, 77, 1)
	var second := JoustSim.play_out(_cfg, setup, 77, 1)
	assert_eq(_describe(first), _describe(second))
	var scripted := [_sim(), _sim()]
	for sim: JoustSim in scripted:
		var sloppy := Scripted.new(1)
		sloppy.spur_error = 0.1
		sloppy.target = RIM
		_play(sim, Scripted.new(0), sloppy)
	assert_eq(_describe(scripted[0].result()), _describe(scripted[1].result()))


func test_inputs_are_validated() -> void:
	var sim := _sim()
	var wild := JoustInput.new()
	wild.aim = Vector2(9, -9)
	wild.shield = Vector2(INF, 0)
	wild.spur = 7.0
	wild.strike = NAN
	_run_until_with(sim, wild, JoustState.Phase.AIM)
	_run_until_with(sim, wild, JoustState.Phase.CLASH)
	var rider := sim.state.riders[0]
	assert_lte(absf(rider.hand.x), _cfg.aim_range + EPSILON)
	assert_eq(rider.shield, Vector2.ZERO)
	assert_eq(rider.tempo, _cfg.tempo_start, "a press outside the tick is no press")
	assert_true(is_nan(rider.strike_offset))


func _sim() -> JoustSim:
	return JoustSim.new(_cfg, JoustSetup.new())


func _passive(rider: int) -> Scripted:
	var scripted := Scripted.new(rider)
	scripted.spur_beats = []
	scripted.aim = false
	scripted.strike_offset = NAN
	return scripted


func _run_pass(sim: JoustSim, a: Scripted, b: Scripted) -> void:
	while sim.state.pass_count == 0 or sim.state.phase != JoustState.Phase.CLASH:
		sim.step(a.input(sim), b.input(sim))
	while sim.state.phase == JoustState.Phase.CLASH:
		sim.step(a.input(sim), b.input(sim))


func _run_until(sim: JoustSim, a: Scripted, b: Scripted, phase: JoustState.Phase) -> void:
	while sim.state.phase != phase:
		sim.step(a.input(sim), b.input(sim))


func _run_until_with(sim: JoustSim, input: JoustInput, phase: JoustState.Phase) -> void:
	while sim.state.phase != phase:
		sim.step(input, JoustInput.new())


func _play(sim: JoustSim, a: Scripted, b: Scripted) -> void:
	var limit := sim.max_ticks()
	while not sim.is_over() and sim.state.tick < limit:
		sim.step(a.input(sim), b.input(sim))
	assert_true(sim.is_over())


static func _describe(result: JoustResult) -> String:
	return "%s %d:%d fell %d passes %d stance %.4f/%.4f by %d in %.2f s" % [
		result.won, result.player_points, result.opponent_points, result.unseated,
		result.passes, result.player_stance, result.opponent_stance, result.decided_by,
		result.duration
	]
