extends GutTest
## The battle scene as a campaign battle: it plays the given setup with the owners' colours and
## reports the result when the player continues.

var _result: BattleResult = null


func test_campaign_battle_plays_the_setup_and_reports_the_result() -> void:
	var setup := BattleSetup.new()
	setup.attacker.owner = "staufer"
	setup.attacker.add_company("knights", 0.8)
	setup.attacker.add_company("spearmen")
	setup.defender.owner = "church"
	setup.defender.add_company("levy")
	setup.defender.add_company("levy", 0.5)
	var scene := load("res://src/render/battle/battle_main.tscn") as PackedScene
	var battle: Node3D = scene.instantiate()
	battle.call("configure_campaign", setup, PackedInt32Array([-1, -1]), 7)
	battle.connect("battle_finished", func(result: BattleResult) -> void: _result = result)
	add_child_autofree(battle)
	var cfg: CombatConfig = battle.get("_cfg")
	assert_eq(cfg.battle.armies[0].house, "staufer")
	assert_eq(cfg.battle.armies[1].house, "church", "a lord who is no house fights in his colours")
	assert_ne(cfg.battle.armies[1].color, Color.WHITE)
	var sim: BattleSim = battle.get("_sim")
	assert_eq(sim.state.hp[0], sim.state.max_hp[0] * 0.8, "the campaign health carries over")
	var limit := sim.rules.deploy_ticks() + sim.rules.time_limit_ticks() + 1
	while not sim.is_over() and sim.state.tick < limit:
		battle.call("_tick")
	assert_true(sim.is_over())
	var panel: BattleResultPanel = battle.get("_result_panel")
	panel.continue_requested.emit()
	assert_not_null(_result, "continue reports the result")
	assert_eq(_result.attacker_health.size(), 2)
	assert_eq(_result.defender_health.size(), 2)
