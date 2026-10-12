extends GutTest
## The joust scene: a campaign joust between two computer riders runs to the end and reports a
## plausible result; opened directly it is the practice mode.

var _result: JoustResult = null


func test_campaign_joust_rides_to_the_end_and_reports_the_result() -> void:
	var setup := JoustSetup.new()
	setup.house = "wettiner"
	setup.opponent = "elector"
	setup.opponent_skill = 1
	setup.host_province = "MAI"
	var joust := _scene()
	joust.call("configure_campaign", setup, PackedInt32Array([-1, -1]), 11)
	joust.connect("finished", func(result: JoustResult) -> void: _result = result)
	add_child_autofree(joust)
	var sim: JoustSim = joust.get("_sim")
	assert_not_null(sim)
	assert_eq(sim.state.riders[1].owner, "elector", "a lord who is no house rides in his colours")
	var limit := sim.max_ticks()
	while _result == null and sim.state.tick < limit:
		joust.call("_tick")
	assert_not_null(_result, "finished fires without a human rider")
	assert_true(_result.passes >= 1 and _result.passes <= 4)
	assert_between(_result.duration, 60.0, 180.0)
	var constants := (joust.get_script() as GDScript).get_script_constant_map()
	var stand_in: int = constants["STAND_IN_SKILL"]
	var expected := JoustSim.play_out(JoustConfig.load_file(), setup, 11, stand_in)
	assert_eq(_result.won, expected.won, "the scene rides like the headless simulation")
	assert_eq(_result.player_points, expected.player_points)


func test_opened_directly_it_is_the_practice_mode() -> void:
	var joust := _scene()
	add_child_autofree(joust)
	var setup: JoustSetup = joust.get("_setup")
	assert_true(setup.practice)
	var panel: JoustResultPanel = joust.get("_result_panel")
	assert_true((panel.get("_retry") as Button).visible, "practice offers a retry")
	assert_true((panel.get("_quit") as Button).visible, "and a quit button")


func _scene() -> Node3D:
	var scene := load("res://src/render/joust/joust_main.tscn") as PackedScene
	return scene.instantiate()
