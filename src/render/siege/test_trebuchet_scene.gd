extends GutTest
## The trebuchet scene: as a campaign siege with the computer's crew it plays to the end and
## reports what the rules give for that seed; opened directly it is the practice.

const SCENE := "res://src/render/siege/trebuchet_main.tscn"
const STEP := 0.05
const MAX_STEPS := 8000

var _result: TrebuchetResult = null


func test_campaign_siege_plays_to_the_end_and_reports() -> void:
	var cfg := SiegeConfig.load_file()
	var setup := TrebuchetSetup.new()
	setup.attacker_house = "staufer"
	setup.defender_owner = "welfen"
	setup.wall_level = 3
	setup.castle_level = 3
	setup.trebuchets = 1
	setup.garrison_health = 0.9
	setup.wall_damage = 0.1
	var siege := (load(SCENE) as PackedScene).instantiate()
	siege.call("configure_campaign", setup, PackedInt32Array([-1]), 11)
	siege.connect("finished", func(result: TrebuchetResult) -> void: _result = result)
	add_child_autofree(siege)
	var steps := 0
	while _result == null and steps < MAX_STEPS:
		siege.call("advance", STEP)
		steps += 1
	assert_not_null(_result, "the siege reports back")
	if _result == null:
		return
	var crew := TrebuchetAimer.new(cfg, cfg.campaign_skill)
	var expected := crew.play(TrebuchetSim.new(cfg, setup, 11))
	assert_eq(_result.breach, expected.breach)
	assert_eq(_result.breach_part, expected.breach_part)
	assert_eq(_result.wall_damage, expected.wall_damage)
	assert_eq(_result.shots_fired, expected.shots_fired)
	assert_gte(_result.wall_damage, 0.1, "earlier damage stays")
	assert_lte(_result.wall_damage, 1.0)
	assert_gt(_result.shots_fired, 0)
	var minutes := steps * STEP / 60.0
	assert_between(minutes, 0.3, 3.0, "a computer siege plays in under three minutes")


func test_opened_directly_it_is_the_practice() -> void:
	var siege := (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(siege)
	var sim: TrebuchetSim = siege.get("_sim")
	assert_not_null(sim)
	assert_true(sim.setup.is_practice)
	assert_eq(sim.setup.layout_key(), "province_2")
	var castle_view: Node3D = siege.get("_castle_view")
	assert_gt(castle_view.get_child_count(), sim.castle.part_count(), "parts and the ring stand")
	siege.call("_retry")
	var again: TrebuchetSim = siege.get("_sim")
	assert_ne(again, sim, "again starts a fresh bombardment")
	assert_eq(again.shots_fired, 0)
