extends GutTest
## The raid scene as a campaign adventure: the computer raids the given setup headless and the
## scene reports a plausible result when the player continues.

const MAX_FRAMES := 2000
const SCENE := preload("res://src/render/merchant/merchant_main.tscn")

var _result: MerchantResult = null


func test_campaign_raid_plays_the_setup_and_reports_the_result() -> void:
	var setup := MerchantSetup.new()
	setup.house = "staufer"
	setup.blade = 3
	setup.companies.assign(["knights", "crossbowmen"])
	setup.escort_skill = 2
	setup.province = "MAI"
	setup.season = 0
	setup.raider_skill = 2
	var raid: Node3D = SCENE.instantiate()
	raid.call("configure_campaign", setup, PackedInt32Array(), 11)
	raid.connect("finished", func(result: MerchantResult) -> void: _result = result)
	add_child_autofree(raid)
	var sim: MerchantSim = raid.get("_sim")
	assert_not_null(sim)
	assert_eq(sim.setup.house, "staufer")
	assert_eq(sim.state.company_count(), 2)
	assert_eq(sim.state.escort_count(), 3)
	var panel: MerchantResultPanel = raid.get("_result_panel")
	var frames := 0
	while not panel.visible and frames < MAX_FRAMES:
		raid.call("_process", 0.1)
		frames += 1
	assert_true(sim.is_over(), "the raid ends")
	assert_true(panel.visible, "the result shows after the outro")
	panel.continue_requested.emit()
	assert_not_null(_result, "continue reports the result")
	assert_eq(_result.wagons_total, 5)
	assert_between(_result.wagons_stopped, 0, 5)
	assert_lte(_result.seconds, 90.05)
	if not _result.leader_captured:
		assert_eq(_result.taler, sim.state.loot())
		assert_between(_result.taler, 30 * _result.wagons_stopped, 40 * _result.wagons_stopped)


func test_practice_offers_retry_and_starts_a_fresh_raid() -> void:
	var raid: Node3D = SCENE.instantiate()
	add_child_autofree(raid)
	var first: MerchantSim = raid.get("_sim")
	assert_true(first.setup.practice)
	var panel: MerchantResultPanel = raid.get("_result_panel")
	panel.retry_requested.emit()
	var second: MerchantSim = raid.get("_sim")
	assert_ne(first, second, "retry starts a new raid")
	assert_eq(second.setup.escort_skill, first.setup.escort_skill)
