extends GutTest

const EPSILON := 0.0001
const SEEDS: Array[int] = [0, 1, 17, 42, 1198, 8192, 65535, 2147483647]

var _cfg: CombatConfig


func before_each() -> void:
	_cfg = CombatConfig.load_file()


func test_default_figures_fit_entirely_inside_their_deployment_zones() -> void:
	var rules := _cfg.battle
	for seed_value: int in SEEDS:
		var state := BattleDeployment.create(_cfg, rules.default_setup(), seed_value)
		for f: int in state.fig_pos.size():
			var c := state.fig_company[f]
			var body := BattleDeployment.figure_radius(state, rules, c)
			var at := state.fig_pos[f]
			var low_x := 0.0 if state.side[c] == 0 else rules.field_size.x - rules.deploy_depth
			var high_x := rules.deploy_depth if state.side[c] == 0 else rules.field_size.x
			var label := _figure_label(state, f, seed_value)
			assert_gte(at.x - body, low_x - EPSILON, label + " left edge")
			assert_lte(at.x + body, high_x + EPSILON, label + " right edge")
			assert_gte(at.y - body, -EPSILON, label + " top edge")
			assert_lte(at.y + body, rules.field_size.y + EPSILON, label + " bottom edge")


func test_default_figures_start_clear_of_solid_obstacles() -> void:
	var rules := _cfg.battle
	for seed_value: int in SEEDS:
		var state := BattleDeployment.create(_cfg, rules.default_setup(), seed_value)
		for f: int in state.fig_pos.size():
			var c := state.fig_company[f]
			var body := BattleDeployment.figure_radius(state, rules, c)
			for obstacle: Vector3 in rules.obstacles:
				var clearance := state.fig_pos[f].distance_to(Vector2(obstacle.x, obstacle.y))
				assert_gte(clearance + EPSILON, obstacle.z + body,
					_figure_label(state, f, seed_value) + " solid obstacle %s" % obstacle)


func test_default_companies_have_separate_starting_footprints() -> void:
	var state := BattleDeployment.create(_cfg, _cfg.battle.default_setup(), SEEDS[0])
	for c: int in state.company_count():
		for other: int in range(c + 1, state.company_count()):
			var gap := state.pos[c].distance_to(state.pos[other])
			assert_gte(gap + EPSILON, state.radius[c] + state.radius[other],
				"starting companies %d and %d overlap" % [c, other])


func test_matching_armies_have_mirrored_company_layouts() -> void:
	var state := BattleDeployment.create(_cfg, _cfg.battle.default_setup(), SEEDS[4])
	var width := _cfg.battle.field_size.x
	var height := _cfg.battle.field_size.y
	for group: int in CombatConfig.GROUPS.size():
		var left := state.members(0, group)
		var right := state.members(1, group)
		assert_eq(left.size(), right.size(), "default armies have matching groups")
		for i: int in mini(left.size(), right.size()):
			var a := left[i]
			var b := right[i]
			assert_eq(state.unit_ids[a], state.unit_ids[b])
			assert_almost_eq(state.pos[a].x + state.pos[b].x, width, EPSILON)
			assert_almost_eq(state.pos[a].y + state.pos[b].y, height, EPSILON)
			assert_eq(state.radius[a], state.radius[b])
			assert_almost_eq(state.facing_vector(a).dot(state.facing_vector(b)), -1.0, EPSILON)


func test_spawn_repeats_for_the_same_seed_and_changes_only_jitter_for_another() -> void:
	var setup := _cfg.battle.default_setup()
	var a := BattleDeployment.create(_cfg, setup, SEEDS[4])
	var b := BattleDeployment.create(_cfg, setup, SEEDS[4])
	var different := BattleDeployment.create(_cfg, setup, SEEDS[4] + 1)
	assert_eq(a.checksum(), b.checksum())
	assert_eq(a.fig_jitter, b.fig_jitter)
	assert_eq(a.fig_pos, b.fig_pos)
	assert_eq(a.pos, different.pos, "seed does not move company anchors")
	assert_eq(a.facing, different.facing, "seed does not rotate the army")
	assert_eq(a.side_groups, different.side_groups, "seed does not change command groups")
	assert_ne(a.fig_jitter, different.fig_jitter)
	assert_ne(a.fig_pos, different.fig_pos)


func test_idle_deployment_keeps_figures_inside_the_field_and_clear_of_obstacles() -> void:
	var sim := BattleSim.new(_cfg, _cfg.battle.default_setup(), SEEDS[4])
	for tick: int in sim.rules.deploy_ticks():
		sim.step(BattleInput.new(), BattleInput.new())
	assert_eq(sim.state.phase, BattleState.Phase.DEPLOY)
	for f: int in sim.state.fig_pos.size():
		var c := sim.state.fig_company[f]
		var body := BattleDeployment.figure_radius(sim.state, sim.rules, c)
		var at := sim.state.fig_pos[f]
		var low_x := 0.0 if sim.state.side[c] == 0 else sim.rules.field_size.x - sim.rules.deploy_depth
		var high_x := sim.rules.deploy_depth if sim.state.side[c] == 0 else sim.rules.field_size.x
		assert_gte(at.x - body, low_x - EPSILON, "idle deployment left edge")
		assert_lte(at.x + body, high_x + EPSILON, "idle deployment right edge")
		assert_gte(at.y - body, -EPSILON, "idle deployment top edge")
		assert_lte(at.y + body, sim.rules.field_size.y + EPSILON, "idle deployment bottom edge")
		for obstacle: Vector3 in sim.rules.obstacles:
			assert_gte(at.distance_to(Vector2(obstacle.x, obstacle.y)) + EPSILON,
				obstacle.z + body, "idle deployment solid obstacle")


func _figure_label(state: BattleState, figure: int, seed_value: int) -> String:
	var company := state.fig_company[figure]
	return "seed %d, side %d, %s company %d figure %d" % [
		seed_value, state.side[company], state.unit_ids[company], company, figure
	]
