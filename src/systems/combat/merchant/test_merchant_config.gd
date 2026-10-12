extends GutTest
## Merchant train data (GDD "Kaufmannszug") and the setup the campaign passes in.

var _cfg: MerchantConfig
var _combat: CombatConfig


func before_all() -> void:
	_cfg = MerchantConfig.load_file()
	_combat = CombatConfig.load_file()


func test_data_loads() -> void:
	assert_not_null(_cfg)
	assert_eq(_cfg.escort_skills.size(), MerchantConfig.SKILLS)
	assert_eq(_cfg.raider_skills.size(), MerchantConfig.SKILLS)


func test_five_wagons_reach_the_gate_after_90_seconds() -> void:
	assert_eq(_cfg.wagons, 5)
	assert_eq(_cfg.train_seconds, 90.0)
	var rear := _cfg.wagon_start(_cfg.wagons - 1)
	assert_almost_eq(rear + _cfg.wagon_speed * _cfg.train_seconds, _cfg.gate_x(), 1e-9)
	assert_lt(_cfg.wagon_start(0), _cfg.gate_x(), "the leading wagon starts before the gate")


func test_two_to_four_escorts_and_more_for_better_escorts() -> void:
	assert_eq(_cfg.min_escorts(), 2)
	assert_eq(_cfg.max_escorts(), 4)
	for skill: int in range(1, MerchantConfig.SKILLS):
		var weaker := _cfg.escort_skill(skill - 1)
		var stronger := _cfg.escort_skill(skill)
		assert_true(stronger.count >= weaker.count)
		assert_lt(stronger.windup_seconds, weaker.windup_seconds, "veterans strike sooner")


func test_each_wagon_carries_30_to_40_taler() -> void:
	assert_eq(_cfg.cargo_min, 30)
	assert_eq(_cfg.cargo_max, 40)


func test_the_leader_brings_up_to_two_companies() -> void:
	assert_eq(_cfg.max_companies, 2)
	assert_gte(_cfg.ambush_at.size(), _cfg.max_companies)


func test_broken_values_are_all_reported() -> void:
	var data: Dictionary = DataReader.load_json(MerchantConfig.PATH)
	var train: Dictionary = data["train"]
	train["wagons"] = 0
	train["cargo_taler"] = [40, 30]
	var escorts: Dictionary = data["escorts"]
	var skills: Array = escorts["skills"]
	skills.pop_back()
	var raiders: Array = data["raider_ai"]
	var sloppy: Dictionary = raiders[0]
	sloppy.erase("aim_factor")
	var crossbow: Dictionary = data["crossbow"]
	crossbow["range"] = [9]
	var reader := DataReader.new()
	MerchantConfig.read(reader, data)
	var report := "\n".join(reader.errors)
	for expected: String in [
		"train.wagons", "train.cargo_taler", "escorts.skills: expected 4",
		"raider_ai[0].aim_factor: missing", "crossbow.range",
	]:
		assert_string_contains(report, expected)


func test_setup_problems_are_reported_and_clamped_for_play() -> void:
	var setup := MerchantSetup.new()
	setup.blade = 9
	setup.companies.assign(["knights", "trebuchet", "dragons", "levy"])
	setup.escort_skill = 7
	setup.escort_count = 6
	setup.raider_skill = -1
	var report := "\n".join(setup.errors(_cfg, _combat))
	for expected: String in [
		"blade 9", "4 companies", "trebuchet", "dragons", "escort skill 7", "6 escorts",
		"raider skill -1",
	]:
		assert_string_contains(report, expected)
	var playable := setup.playable(_cfg, _combat)
	assert_eq(playable.blade, MerchantSetup.MAX_BLADE)
	assert_eq(playable.companies, ["knights", "levy"] as Array[String])
	assert_eq(playable.escort_skill, MerchantConfig.SKILLS - 1)
	assert_eq(playable.escort_count, _cfg.max_escorts())
	assert_eq(playable.raider_skill, 0)


func test_default_setup_is_valid() -> void:
	var setup := MerchantSetup.new()
	setup.companies.assign(["spearmen", "crossbowmen"])
	assert_eq(setup.errors(_cfg, _combat), PackedStringArray())
	var playable := setup.playable(_cfg, _combat)
	assert_eq(playable.escort_count, _cfg.escort_skill(setup.escort_skill).count)
