extends GutTest
## The raid scene headless: as a campaign raid it plays the given setup with the computer leader
## and reports through `finished`; opened alone it starts the practice.

const SCENE := "res://src/render/raid/raid_main.tscn"

var _result: RaidResult = null
var _reports: int = 0


func before_each() -> void:
	_result = null
	_reports = 0


func test_campaign_raid_plays_the_setup_and_reports_the_result() -> void:
	var setup := RaidSetup.new()
	setup.raider_house = "staufer"
	setup.defender_owner = "church"
	setup.target = "regalia"
	setup.castle_level = 2
	setup.guard_skill = 1
	setup.blade = 4
	var raid := _open(setup, 11)
	var sim: RaidSim = raid.get("_sim")
	assert_not_null(sim, "the raid starts at once")
	assert_eq(sim.setup.target, "regalia")
	assert_false(sim.setup.practice, "a campaign raid counts")
	var figures: RaidFigures = raid.get("_figures")
	assert_eq(figures.guards.size(), sim.state.guards.size(), "every guard is on screen")
	await wait_until(func() -> bool: return _result != null, 20.0)
	assert_not_null(_result, "finished fires")
	if _result == null:
		return
	assert_eq(_reports, 1, "reported once")
	assert_eq(_result.target, "regalia")
	assert_between(_result.time_used, 1.0, 120.0)
	assert_false(_result.practice)
	assert_eq(_result.success, _result.outcome == RaidResult.Outcome.SUCCESS)
	assert_true(_result.guards_defeated + _result.guards_avoided >= 1, "it met the guards")
	assert_eq(figures.guards.size(), sim.state.guards.size(), "reinforcements appear too")


func test_broken_campaign_setup_reports_a_failed_raid() -> void:
	var setup := RaidSetup.new()
	setup.target = "kitchen"
	_open(setup, 3)
	await wait_until(func() -> bool: return _result != null, 5.0)
	assert_push_error("unknown target")
	assert_not_null(_result)
	if _result != null:
		assert_false(_result.success)
		assert_eq(_result.time_used, 0.0)


func test_opened_alone_it_is_the_practice() -> void:
	var raid: Node3D = (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(raid)
	var sim: RaidSim = raid.get("_sim")
	assert_not_null(sim, "headless, the computer plays a practice raid")
	assert_true(sim.setup.practice)


func _open(setup: RaidSetup, seed_value: int) -> Node3D:
	var raid: Node3D = (load(SCENE) as PackedScene).instantiate()
	raid.call("configure_campaign", setup, PackedInt32Array([-1]), seed_value)
	raid.connect("finished", _on_finished)
	add_child_autofree(raid)
	return raid


func _on_finished(result: RaidResult) -> void:
	_result = result
	_reports += 1
