extends GutTest
## Dust clouds and comic falls of the battle presentation.

var _cfg: CombatConfig


func before_each() -> void:
	_cfg = CombatConfig.load_file()


func test_dust_burst_rises_and_fades() -> void:
	var dust := BattleDust.new()
	add_child_autofree(dust)
	var sim := BattleSim.new(_cfg, _cfg.battle.default_setup(), 1198)
	dust.burst(Vector2(150, 90), 8, 3.0)
	dust.update_view(sim.state, sim.state.pos, 0.1)
	assert_eq(dust.active(), 8, "eight puffs show")
	dust.update_view(sim.state, sim.state.pos, BattleDust.LIFE)
	assert_eq(dust.active(), 0, "they are gone after their life")


func test_lost_figures_tumble_but_fled_companies_do_not() -> void:
	var sim := BattleSim.new(_cfg, _cfg.battle.default_setup(), 1198)
	var tumblers := BattleTumblers.new()
	add_child_autofree(tumblers)
	tumblers.setup(sim.state, _cfg.battle.armies)
	var state := sim.state
	state.hp[0] = state.max_hp[0] * 0.5
	state.status[1] = BattleState.Status.FLED
	tumblers.update_view(state, 0.1)
	assert_eq(tumblers.active(), state.fig_count[0] - state.alive_figures(0), "only lost figures fall")
	tumblers.update_view(state, BattleTumblers.FLIGHT + BattleTumblers.LIE + BattleTumblers.SHRINK)
	assert_eq(tumblers.active(), 0, "the fallen vanish")
